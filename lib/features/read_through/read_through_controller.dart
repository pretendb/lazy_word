import 'package:flutter/foundation.dart';

import '../../data/card_dao.dart';
import '../../domain/flash_card.dart';

class ReadThroughController extends ChangeNotifier {
  ReadThroughController(this._cardDao, this.deckId);

  final CardDao _cardDao;
  final String deckId;

  List<FlashCard> cards = [];
  bool loading = true;
  String? error;
  int readCount = 0;
  int totalCount = 0;

  FlashCard? get current => cards.isEmpty ? null : cards.first;
  double get progress => totalCount == 0 ? 0 : readCount / totalCount;
  int get progressPercent => (progress * 100).round();

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      cards = await _cardDao.unreadCards(deckId);
      final progress = await _cardDao.readProgress(deckId);
      readCount = progress.read;
      totalCount = progress.total;
    } catch (exception) {
      error = '$exception';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> swipe({required bool known}) async {
    final card = current;
    if (card == null) return;
    cards.removeAt(0);
    if (readCount < totalCount) readCount += 1;
    notifyListeners();
    try {
      await _cardDao.markRead(card, known: known);
    } catch (exception) {
      cards.insert(0, card);
      if (readCount > 0) readCount -= 1;
      error = '$exception';
      notifyListeners();
    }
  }
}
