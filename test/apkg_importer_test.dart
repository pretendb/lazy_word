import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_word/import/apkg_importer.dart';

void main() {
  test('prefers modern collection database over compatibility database', () {
    final archive = Archive()
      ..addFile(ArchiveFile('collection.anki2', 0, const []))
      ..addFile(ArchiveFile('collection.anki21', 0, const []));

    final files = orderedCollectionFiles(archive);

    expect(files.map((file) => file.name), [
      'collection.anki21',
      'collection.anki2',
    ]);
  });
}
