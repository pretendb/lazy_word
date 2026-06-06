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
  int currentIndex = 0;
  final Set<String> _readCardIds = {};

  FlashCard? get current {
    if (currentIndex < 0 || currentIndex >= cards.length) return null;
    return cards[currentIndex];
  }

  double get progress => totalCount == 0 ? 0 : readCount / totalCount;
  int get progressPercent => (progress * 100).round();
  double get seekValue => currentIndex.clamp(0, totalCount).toDouble();
  int get positionNumber {
    if (totalCount == 0) return 0;
    return (currentIndex + 1).clamp(1, totalCount);
  }

  bool get completed => totalCount > 0 && currentIndex >= totalCount;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      cards = await _cardDao.deckCards(deckId);
      totalCount = cards.length;
      _readCardIds
        ..clear()
        ..addAll(
          cards.where((card) => card.readSeenCount > 0).map((card) => card.id),
        );
      readCount = _readCardIds.length;
      currentIndex = cards.indexWhere((card) => card.readSeenCount == 0);
      if (currentIndex == -1) currentIndex = cards.length;
    } catch (exception) {
      error = '$exception';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void seekTo(double value) {
    if (totalCount == 0) return;
    currentIndex = value.round().clamp(0, totalCount);
    notifyListeners();
  }

  Future<void> swipe({required bool known}) async {
    final card = current;
    if (card == null) return;
    final wasAlreadyRead = _readCardIds.contains(card.id);
    if (!wasAlreadyRead) {
      _readCardIds.add(card.id);
      readCount = _readCardIds.length;
    }
    if (currentIndex < cards.length) currentIndex += 1;
    notifyListeners();
    try {
      await _cardDao.markRead(card, known: known);
    } catch (exception) {
      if (currentIndex > 0) currentIndex -= 1;
      if (!wasAlreadyRead) {
        _readCardIds.remove(card.id);
        readCount = _readCardIds.length;
      }
      error = '$exception';
      notifyListeners();
    }
  }
}
