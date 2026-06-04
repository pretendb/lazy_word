import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors.dart';
import '../../domain/deck.dart';
import '../../import/apkg_importer.dart';

class ImportDeckController extends ChangeNotifier {
  ImportDeckController(this._importer);

  final ApkgImporter _importer;

  bool isImporting = false;
  String progress = '';
  String? error;

  Future<Deck?> chooseAndImport() async {
    error = null;
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apkg'],
    );
    final path = selection?.files.single.path;
    if (path == null) return null;

    isImporting = true;
    progress = 'Selecting file...';
    notifyListeners();
    try {
      final result = await _importer.importFromFile(
        File(path),
        onProgress: (message) {
          progress = message;
          notifyListeners();
        },
      );
      return result.deck;
    } on AppException catch (exception) {
      error = exception.message;
      return null;
    } catch (exception) {
      error = 'Import failed: $exception';
      return null;
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }
}
