import 'dart:math';

import 'unknown_card.dart';

class ReviewScheduler {
  ReviewScheduler({Random? random}) : _random = random ?? Random();

  final Random _random;

  UnknownCard? select(List<UnknownCard> cards) {
    if (cards.isEmpty) return null;
    final totalWeight = cards.fold<double>(
      0,
      (sum, card) => sum + card.reviewWeight.clamp(1.0, 20.0),
    );
    final target = _random.nextDouble() * totalWeight;
    var cumulative = 0.0;
    for (final card in cards) {
      cumulative += card.reviewWeight.clamp(1.0, 20.0);
      if (cumulative >= target) return card;
    }
    return cards.last;
  }
}
