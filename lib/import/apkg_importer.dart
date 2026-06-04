import 'dart:convert';
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

      final mediaPaths = await _extractMedia(archive, deckId);
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
          cards = await _parser.parse(
            collectionPath,
            deckId,
            mediaPaths: mediaPaths,
          );
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
        _mediaRows(cards),
      );
      await _paths.writeCurrentDeckId(deck.id);
      await _paths.removeOtherDeckMedia(deck.id);
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

  Future<Map<String, String>> _extractMedia(
    Archive archive,
    String deckId,
  ) async {
    final manifestEntry = archive.files.where(
      (entry) => entry.isFile && p.basename(entry.name) == 'media',
    );
    if (manifestEntry.isEmpty) return const {};
    final manifest =
        jsonDecode(utf8.decode(manifestEntry.first.content as List<int>))
            as Map<String, dynamic>;
    final archiveFiles = {
      for (final entry in archive.files.where((entry) => entry.isFile))
        entry.name: entry,
    };
    final directory = await _paths.createDeckMediaDirectory(deckId);
    final paths = <String, String>{};
    for (final entry in manifest.entries) {
      final filename = entry.value as String?;
      final asset = archiveFiles[entry.key];
      if (filename == null || asset == null || p.isAbsolute(filename)) continue;
      final safeName =
          '${sha256.convert(filename.codeUnits)}${p.extension(filename)}';
      final file = File(p.join(directory.path, safeName));
      await file.writeAsBytes(asset.content as List<int>, flush: true);
      paths[filename] = file.path;
    }
    return paths;
  }

  List<Map<String, Object?>> _mediaRows(List<FlashCard> cards) {
    final rows = <Map<String, Object?>>[];
    for (final card in cards) {
      for (final image in card.images) {
        rows.add(_mediaRow(card.id, image.filename, image.localPath, 'image'));
      }
      for (final audio in card.audio) {
        rows.add(_mediaRow(card.id, audio.filename, audio.localPath, 'audio'));
      }
    }
    return rows;
  }

  Map<String, Object?> _mediaRow(
    String cardId,
    String filename,
    String localPath,
    String type,
  ) => {
    'id': sha256.convert('$cardId|$type|$filename'.codeUnits).toString(),
    'card_id': cardId,
    'file_name': filename,
    'local_path': localPath,
    'media_type': type,
  };
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
