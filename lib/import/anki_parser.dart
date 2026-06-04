import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../domain/flash_card.dart';
import 'html_cleaner.dart';

class AnkiParser {
  Future<List<FlashCard>> parse(String databasePath, String deckId) async {
    final factory = Platform.isLinux || Platform.isWindows
        ? ffi.databaseFactoryFfi
        : sqflite.databaseFactory;
    final database = await factory.openDatabase(
      databasePath,
      options: sqflite.OpenDatabaseOptions(
        readOnly: true,
        singleInstance: false,
      ),
    );
    try {
      final rows = await database.rawQuery('''
        SELECT c.id AS card_id, n.id AS note_id, n.flds AS fields
        FROM cards c
        INNER JOIN notes n ON n.id = c.nid
        ORDER BY c.id
      ''');
      final now = DateTime.now().millisecondsSinceEpoch;
      final cards = <FlashCard>[];
      for (final row in rows) {
        final rawFields = row['fields'] as String? ?? '';
        final fields = rawFields.split('\u001f');
        if (fields.length < 2) continue;
        final front = HtmlCleaner.clean(fields[0]);
        final back = HtmlCleaner.clean(fields[1]);
        if (front.isEmpty || back.isEmpty) continue;
        final noteId = '${row['note_id']}';
        final cardId = '${row['card_id']}';
        cards.add(
          FlashCard(
            id: stableCardId(deckId, noteId, cardId, front, back),
            deckId: deckId,
            ankiNoteId: noteId,
            ankiCardId: cardId,
            front: front,
            back: back,
            rawFields: rawFields,
            createdAt: now,
          ),
        );
      }
      return cards;
    } finally {
      await database.close();
    }
  }

  static String stableCardId(
    String deckId,
    String noteId,
    String cardId,
    String front,
    String back,
  ) {
    return sha256
        .convert('$deckId|$noteId|$cardId|$front|$back'.codeUnits)
        .toString();
  }

  // TODO: Support model-aware field mapping, cloze cards, media, and HTML rendering.
}
