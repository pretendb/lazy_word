class FlashCard {
  const FlashCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    this.ankiNoteId,
    this.ankiCardId,
    this.rawFields,
    this.readSeenCount = 0,
    this.lastReadAt,
  });

  final String id;
  final String deckId;
  final String? ankiNoteId;
  final String? ankiCardId;
  final String front;
  final String back;
  final String? rawFields;
  final int readSeenCount;
  final int? lastReadAt;
  final int createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'deck_id': deckId,
    'anki_note_id': ankiNoteId,
    'anki_card_id': ankiCardId,
    'front': front,
    'back': back,
    'raw_fields': rawFields,
    'read_seen_count': readSeenCount,
    'last_read_at': lastReadAt,
    'created_at': createdAt,
  };

  factory FlashCard.fromMap(Map<String, Object?> map) => FlashCard(
    id: map['id']! as String,
    deckId: map['deck_id']! as String,
    ankiNoteId: map['anki_note_id'] as String?,
    ankiCardId: map['anki_card_id'] as String?,
    front: map['front']! as String,
    back: map['back']! as String,
    rawFields: map['raw_fields'] as String?,
    readSeenCount: map['read_seen_count']! as int,
    lastReadAt: map['last_read_at'] as int?,
    createdAt: map['created_at']! as int,
  );
}
