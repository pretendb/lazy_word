import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../core/app_paths.dart';
import '../core/errors.dart';
import '../data/deck_dao.dart';
import '../domain/deck.dart';
import '../domain/flash_card.dart';
import 'anki_parser.dart';

typedef ImportProgress = void Function(String message);

class ImportResult {
  const ImportResult(this.deck);

  final Deck deck;
}

class ApkgImporter {
  ApkgImporter(this._paths, this._deckDao, {AnkiParser? parser})
    : _parser = parser ?? AnkiParser();

  final AppPaths _paths;
  final DeckDao _deckDao;
  final AnkiParser _parser;

  Future<ImportResult> importFromFile(
    File file, {
    ImportProgress? onProgress,
  }) async {
    if (p.extension(file.path).toLowerCase() != '.apkg') {
      throw const AppException('Please choose a file ending in .apkg.');
    }
    if (!await file.exists()) {
      throw const AppException('The selected file no longer exists.');
    }

    final workDirectory = await _paths.createImportDirectory();
    try {
      onProgress?.call('Copying file...');
      final copied = await file.copy(p.join(workDirectory.path, 'deck.apkg'));
      final bytes = await copied.readAsBytes();
      final deckId = sha256.convert(bytes).toString();

      onProgress?.call('Extracting package...');
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        throw const AppException(
          'The selected .apkg is not a valid zip archive.',
        );
      }
      final collections = orderedCollectionFiles(archive);
      if (collections.isEmpty) {
        throw const AppException(
          'No supported Anki collection database was found in the package.',
        );
      }

      onProgress?.call('Reading Anki database...');
      var cards = <FlashCard>[];
      Object? lastParseError;
      for (var index = 0; index < collections.length; index++) {
        final collection = collections[index];
        final collectionPath = p.join(
          workDirectory.path,
          'collection_$index.sqlite',
        );
        await File(collectionPath).writeAsBytes(
          Uint8List.fromList(collection.content as List<int>),
          flush: true,
        );
        try {
          cards = await _parser.parse(collectionPath, deckId);
          if (cards.isNotEmpty) break;
        } catch (error) {
          lastParseError = error;
        }
      }
      if (cards.isEmpty) {
        if (lastParseError != null) {
          throw AppException(
            'Anki collection databases could not be read: $lastParseError',
          );
        }
        throw const AppException(
          'No valid cards were found. Cards need non-empty first and second fields.',
        );
      }

      onProgress?.call('Saving local database...');
      final sourceName = p.basename(file.path);
      final deck = Deck(
        id: deckId,
        name: p.basenameWithoutExtension(sourceName),
        sourceFileName: sourceName,
        importedAt: DateTime.now().millisecondsSinceEpoch,
        cardCount: cards.length,
      );
      await _deckDao.replaceDeck(
        deck,
        cards.map((card) => card.toMap()).toList(),
      );
      await _paths.writeCurrentDeckId(deck.id);
      onProgress?.call('Import complete.');
      return ImportResult(deck);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Import failed: $error');
    } finally {
      try {
        await workDirectory.delete(recursive: true);
      } catch (_) {
        // Temporary cleanup failure must not invalidate a successful import.
      }
    }
  }
}

List<ArchiveFile> orderedCollectionFiles(Archive archive) {
  Iterable<ArchiveFile> filesNamed(String name) {
    return archive.files.where(
      (entry) => entry.isFile && p.basename(entry.name) == name,
    );
  }

  return [
    ...filesNamed('collection.anki21'),
    ...filesNamed('collection.anki2'),
  ];
}
