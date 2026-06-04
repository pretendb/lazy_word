enum CardType { basic, image, audio, cloze, mixed }

class ImageAttachment {
  const ImageAttachment({required this.filename, required this.localPath});

  final String filename;
  final String localPath;
}

class AudioAttachment {
  const AudioAttachment({required this.filename, required this.localPath});

  final String filename;
  final String localPath;
}

class FlashCard {
  const FlashCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    this.frontHtml,
    this.backHtml,
    this.images = const [],
    this.audio = const [],
    this.type = CardType.basic,
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
  final String? frontHtml;
  final String? backHtml;
  final List<ImageAttachment> images;
  final List<AudioAttachment> audio;
  final CardType type;
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
    'front_html': frontHtml,
    'back_html': backHtml,
    'card_type': type.name,
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
    frontHtml: map['front_html'] as String?,
    backHtml: map['back_html'] as String?,
    type: CardType.values.firstWhere(
      (value) => value.name == map['card_type'],
      orElse: () => CardType.basic,
    ),
    rawFields: map['raw_fields'] as String?,
    readSeenCount: map['read_seen_count']! as int,
    lastReadAt: map['last_read_at'] as int?,
    createdAt: map['created_at']! as int,
  );

  FlashCard withAttachments({
    required List<ImageAttachment> images,
    required List<AudioAttachment> audio,
  }) => FlashCard(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    createdAt: createdAt,
    frontHtml: frontHtml,
    backHtml: backHtml,
    images: images,
    audio: audio,
    type: type,
    ankiNoteId: ankiNoteId,
    ankiCardId: ankiCardId,
    rawFields: rawFields,
    readSeenCount: readSeenCount,
    lastReadAt: lastReadAt,
  );
}
