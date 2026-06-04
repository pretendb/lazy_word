import 'package:sqflite/sqflite.dart';

import '../domain/flash_card.dart';

Future<List<FlashCard>> hydrateCardMedia(
  DatabaseExecutor db,
  List<FlashCard> cards,
) async {
  if (cards.isEmpty) return cards;
  final ids = cards.map((card) => card.id).toList();
  final placeholders = List.filled(ids.length, '?').join(',');
  final rows = await db.rawQuery(
    'SELECT card_id, file_name, local_path, media_type '
    'FROM media WHERE card_id IN ($placeholders)',
    ids,
  );
  final images = <String, List<ImageAttachment>>{};
  final audio = <String, List<AudioAttachment>>{};
  for (final row in rows) {
    final cardId = row['card_id']! as String;
    final filename = row['file_name']! as String;
    final localPath = row['local_path']! as String;
    if (row['media_type'] == 'image') {
      images
          .putIfAbsent(cardId, () => [])
          .add(ImageAttachment(filename: filename, localPath: localPath));
    } else if (row['media_type'] == 'audio') {
      audio
          .putIfAbsent(cardId, () => [])
          .add(AudioAttachment(filename: filename, localPath: localPath));
    }
  }
  return cards
      .map(
        (card) => card.withAttachments(
          images: images[card.id] ?? const [],
          audio: audio[card.id] ?? const [],
        ),
      )
      .toList();
}
