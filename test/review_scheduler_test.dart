import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_word/domain/review_scheduler.dart';
import 'package:lazy_word/domain/unknown_card.dart';

UnknownCard card(String id, double weight) => UnknownCard(
  cardId: id,
  deckId: 'deck',
  knownStreak: 0,
  failureCount: 0,
  reviewWeight: weight,
  addedAt: 0,
);

void main() {
  test('returns null for an empty unknown list', () {
    expect(ReviewScheduler().select([]), isNull);
  });

  test('always returns a member of the supplied list', () {
    final cards = [card('a', 1), card('b', 20), card('c', 3)];
    final scheduler = ReviewScheduler(random: Random(7));

    for (var i = 0; i < 100; i++) {
      expect(cards, contains(scheduler.select(cards)));
    }
  });
}
