import '../domain/deck.dart';
import 'local_db.dart';

class DeckDao {
  DeckDao(this._localDb);

  final LocalDb _localDb;

  Future<Deck?> findById(String id) async {
    final db = await _localDb.database;
    final rows = await db.query('decks', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Deck.fromMap(rows.first);
  }

  Future<void> replaceDeck(
    Deck deck,
    List<Map<String, Object?>> cards,
    List<Map<String, Object?>> media,
  ) async {
    final db = await _localDb.database;
    await db.transaction((txn) async {
      await txn.delete('review_events');
      await txn.delete('unknown_cards');
      await txn.delete('media');
      await txn.delete('cards');
      await txn.delete('decks');
      await txn.insert('decks', deck.toMap());
      final batch = txn.batch();
      for (final card in cards) {
        batch.insert('cards', card);
      }
      for (final attachment in media) {
        batch.insert('media', attachment);
      }
      await batch.commit(noResult: true);
    });
  }
}
