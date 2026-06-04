import '../domain/review_event.dart';
import 'local_db.dart';

class ReviewEventDao {
  ReviewEventDao(this._localDb);

  final LocalDb _localDb;

  Future<void> insert(ReviewEvent event) async {
    final db = await _localDb.database;
    await db.insert('review_events', event.toMap());
  }
}
