import '../domain/flash_card.dart';
import '../domain/review_event.dart';
import '../domain/unknown_card.dart';
import 'local_db.dart';

class UnknownCardDao {
  UnknownCardDao(this._localDb);

  final LocalDb _localDb;

  Future<List<UnknownCard>> list(String deckId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'unknown_cards',
      where: 'deck_id = ?',
      whereArgs: [deckId],
    );
    return rows.map(UnknownCard.fromMap).toList();
  }

  Future<FlashCard?> findCard(String cardId) async {
    final db = await _localDb.database;
    final rows = await db.query('cards', where: 'id = ?', whereArgs: [cardId]);
    return rows.isEmpty ? null : FlashCard.fromMap(rows.first);
  }

  Future<void> review(UnknownCard card, {required bool known}) async {
    final db = await _localDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      if (known && card.knownStreak + 1 >= 3) {
        await txn.delete(
          'unknown_cards',
          where: 'card_id = ?',
          whereArgs: [card.cardId],
        );
      } else if (known) {
        await txn.update(
          'unknown_cards',
          {
            'known_streak': card.knownStreak + 1,
            'review_weight': (card.reviewWeight - 0.5).clamp(1.0, 20.0),
            'last_reviewed_at': now,
          },
          where: 'card_id = ?',
          whereArgs: [card.cardId],
        );
      } else {
        await txn.update(
          'unknown_cards',
          {
            'known_streak': 0,
            'failure_count': card.failureCount + 1,
            'review_weight': (card.reviewWeight + 2).clamp(1.0, 20.0),
            'last_reviewed_at': now,
          },
          where: 'card_id = ?',
          whereArgs: [card.cardId],
        );
      }
      await txn.insert(
        'review_events',
        ReviewEvent(
          cardId: card.cardId,
          deckId: card.deckId,
          mode: 'unknown_review',
          action: known ? 'known' : 'unknown',
          createdAt: now,
        ).toMap(),
      );
    });
  }
}
