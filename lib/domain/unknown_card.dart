class UnknownCard {
  const UnknownCard({
    required this.cardId,
    required this.deckId,
    required this.knownStreak,
    required this.failureCount,
    required this.reviewWeight,
    required this.addedAt,
    this.lastReviewedAt,
  });

  final String cardId;
  final String deckId;
  final int knownStreak;
  final int failureCount;
  final double reviewWeight;
  final int addedAt;
  final int? lastReviewedAt;

  factory UnknownCard.fromMap(Map<String, Object?> map) => UnknownCard(
    cardId: map['card_id']! as String,
    deckId: map['deck_id']! as String,
    knownStreak: map['known_streak']! as int,
    failureCount: map['failure_count']! as int,
    reviewWeight: (map['review_weight']! as num).toDouble(),
    addedAt: map['added_at']! as int,
    lastReviewedAt: map['last_reviewed_at'] as int?,
  );
}
