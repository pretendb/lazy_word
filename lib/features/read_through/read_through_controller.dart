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

  FlashCard? get current => cards.isEmpty ? null : cards.first;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      cards = await _cardDao.unreadCards(deckId);
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
    notifyListeners();
    try {
      await _cardDao.markRead(card, known: known);
    } catch (exception) {
      cards.insert(0, card);
      error = '$exception';
      notifyListeners();
    }
  }
}
