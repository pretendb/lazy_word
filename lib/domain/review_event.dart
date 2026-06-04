class ReviewEvent {
  const ReviewEvent({
    required this.cardId,
    required this.deckId,
    required this.mode,
    required this.action,
    required this.createdAt,
  });

  final String cardId;
  final String deckId;
  final String mode;
  final String action;
  final int createdAt;

  Map<String, Object?> toMap() => {
    'card_id': cardId,
    'deck_id': deckId,
    'mode': mode,
    'action': action,
    'created_at': createdAt,
  };
}
