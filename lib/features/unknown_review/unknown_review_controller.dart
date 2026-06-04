import 'package:flutter/foundation.dart';

import '../../data/unknown_card_dao.dart';
import '../../domain/flash_card.dart';
import '../../domain/review_scheduler.dart';
import '../../domain/unknown_card.dart';

class UnknownReviewController extends ChangeNotifier {
  UnknownReviewController(this._dao, this.deckId, {ReviewScheduler? scheduler})
    : _scheduler = scheduler ?? ReviewScheduler();

  final UnknownCardDao _dao;
  final ReviewScheduler _scheduler;
  final String deckId;

  UnknownCard? currentUnknown;
  FlashCard? currentCard;
  bool loading = true;
  String? error;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final cards = await _dao.list(deckId);
      currentUnknown = _scheduler.select(cards);
      currentCard = currentUnknown == null
          ? null
          : await _dao.findCard(currentUnknown!.cardId);
    } catch (exception) {
      error = '$exception';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> swipe({required bool known}) async {
    final unknown = currentUnknown;
    if (unknown == null) return;
    try {
      await _dao.review(unknown, known: known);
      await load();
    } catch (exception) {
      error = '$exception';
      notifyListeners();
    }
  }
}
