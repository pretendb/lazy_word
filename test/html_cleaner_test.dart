import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_word/import/html_cleaner.dart';

void main() {
  test('strips HTML and sound tags', () {
    expect(
      HtmlCleaner.clean('<b>Hello</b>&nbsp; [sound:hello.mp3] world'),
      'Hello world',
    );
  });

  test('decodes common entities and normalizes whitespace', () {
    expect(HtmlCleaner.clean('one &amp;  two\nthree'), 'one & two three');
  });
}
