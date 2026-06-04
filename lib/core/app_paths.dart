import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  Future<Directory> get appDirectory async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'lazy_word'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> createImportDirectory() async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      p.join(
        root.path,
        'lazy_word_import_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> get currentDeckFile async {
    final directory = await appDirectory;
    return File(p.join(directory.path, 'current_deck_id'));
  }

  Future<String?> readCurrentDeckId() async {
    final file = await currentDeckFile;
    if (!await file.exists()) return null;
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  Future<void> writeCurrentDeckId(String id) async {
    final file = await currentDeckFile;
    await file.writeAsString(id, flush: true);
  }
}
