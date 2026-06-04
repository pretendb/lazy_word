import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_word/import/anki_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('stable card ID is deterministic and input-sensitive', () {
    final first = AnkiParser.stableCardId(
      'deck',
      'note',
      'card',
      'front',
      'back',
    );
    final second = AnkiParser.stableCardId(
      'deck',
      'note',
      'card',
      'front',
      'back',
    );
    final changed = AnkiParser.stableCardId(
      'deck',
      'note',
      'card',
      'front!',
      'back',
    );

    expect(first, second);
    expect(first, isNot(changed));
  });

  test('preserves model HTML and maps referenced local media', () async {
    final directory = await Directory.systemTemp.createTemp('anki_parser_test');
    final databasePath = '${directory.path}/collection.anki2';
    final database = await databaseFactoryFfi.openDatabase(databasePath);
    await database.execute('CREATE TABLE col (models TEXT)');
    await database.execute(
      'CREATE TABLE notes (id INTEGER, mid INTEGER, flds TEXT)',
    );
    await database.execute(
      'CREATE TABLE cards (id INTEGER, nid INTEGER, ord INTEGER)',
    );
    await database.insert('col', {
      'models': jsonEncode({
        '10': {
          'type': 0,
          'css': '.card { color: red; }',
          'flds': [
            {'name': 'Word', 'ord': 0},
            {'name': 'Meaning', 'ord': 1},
          ],
          'tmpls': [
            {
              'qfmt': '<b>{{Word}}</b><img src="apple.jpg">',
              'afmt': '{{FrontSide}}<i>{{Meaning}}</i>[sound:apple.mp3]',
            },
          ],
        },
      }),
    });
    await database.insert('notes', {
      'id': 20,
      'mid': 10,
      'flds': 'apple\u001fa fruit',
    });
    await database.insert('cards', {'id': 30, 'nid': 20, 'ord': 0});
    await database.close();

    final cards = await AnkiParser().parse(
      databasePath,
      'deck',
      mediaPaths: {
        'apple.jpg': '/local/apple.jpg',
        'apple.mp3': '/local/apple.mp3',
      },
    );

    expect(cards, hasLength(1));
    expect(cards.single.frontHtml, contains('<style>'));
    expect(cards.single.frontHtml, contains('<b>apple</b>'));
    expect(cards.single.backHtml, contains('<i>a fruit</i>'));
    expect(cards.single.backHtml, isNot(contains('<b>apple</b>')));
    expect(cards.single.images.single.localPath, '/local/apple.jpg');
    expect(cards.single.audio.single.localPath, '/local/apple.mp3');
    expect(cards.single.type.name, 'mixed');

    await directory.delete(recursive: true);
  });
}
