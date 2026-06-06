import 'package:sqflite/sqflite.dart';

import '../domain/flash_card.dart';
import '../domain/review_event.dart';
import 'local_db.dart';
import 'media_dao.dart';

class CardDao {
  CardDao(this._localDb);

  final LocalDb _localDb;

  Future<List<FlashCard>> unreadCards(String deckId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'cards',
      where: 'deck_id = ? AND read_seen_count = 0',
      whereArgs: [deckId],
      orderBy: 'created_at, id',
    );
    return hydrateCardMedia(db, rows.map(FlashCard.fromMap).toList());
  }

  Future<({int read, int total})> readProgress(String deckId) async {
    final db = await _localDb.database;
    final row = (await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN read_seen_count > 0 THEN 1 ELSE 0 END) AS read
      FROM cards
      WHERE deck_id = ?
      ''',
      [deckId],
    )).single;
    return (
      read: (row['read'] as int?) ?? 0,
      total: (row['total'] as int?) ?? 0,
    );
  }

  Future<void> markRead(FlashCard card, {required bool known}) async {
    final db = await _localDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE cards SET read_seen_count = read_seen_count + 1, last_read_at = ? WHERE id = ?',
        [now, card.id],
      );
      if (!known) {
        await txn.insert('unknown_cards', {
          'card_id': card.id,
          'deck_id': card.deckId,
          'added_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.insert(
        'review_events',
        ReviewEvent(
          cardId: card.id,
          deckId: card.deckId,
          mode: 'read_through',
          action: known ? 'known' : 'unknown',
          createdAt: now,
        ).toMap(),
      );
    });
  }

  Future<int> unknownCount(String deckId) async {
    final db = await _localDb.database;
    final value = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM unknown_cards WHERE deck_id = ?',
        [deckId],
      ),
    );
    return value ?? 0;
  }
}
