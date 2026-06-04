import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_word/import/anki_parser.dart';

void main() {
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
}
