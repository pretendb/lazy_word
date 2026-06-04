class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.sourceFileName,
    required this.importedAt,
    required this.cardCount,
  });

  final String id;
  final String name;
  final String sourceFileName;
  final int importedAt;
  final int cardCount;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'source_file_name': sourceFileName,
    'imported_at': importedAt,
    'card_count': cardCount,
  };

  factory Deck.fromMap(Map<String, Object?> map) => Deck(
    id: map['id']! as String,
    name: map['name']! as String,
    sourceFileName: map['source_file_name']! as String,
    importedAt: map['imported_at']! as int,
    cardCount: map['card_count']! as int,
  );
}
