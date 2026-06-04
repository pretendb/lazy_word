import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

class LocalDb {
  sqflite.Database? _database;

  Future<sqflite.Database> get database async => _database ??= await _open();

  Future<sqflite.Database> _open() async {
    final factory = Platform.isLinux || Platform.isWindows
        ? ffi.databaseFactoryFfi
        : sqflite.databaseFactory;
    return factory.openDatabase(
      p.join(await factory.getDatabasesPath(), 'lazy_word.db'),
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE decks (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              source_file_name TEXT NOT NULL,
              imported_at INTEGER NOT NULL,
              card_count INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE cards (
              id TEXT PRIMARY KEY,
              deck_id TEXT NOT NULL,
              anki_note_id TEXT,
              anki_card_id TEXT,
              front TEXT NOT NULL,
              back TEXT NOT NULL,
              raw_fields TEXT,
              read_seen_count INTEGER NOT NULL DEFAULT 0,
              last_read_at INTEGER,
              created_at INTEGER NOT NULL,
              FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE unknown_cards (
              card_id TEXT PRIMARY KEY,
              deck_id TEXT NOT NULL,
              known_streak INTEGER NOT NULL DEFAULT 0,
              failure_count INTEGER NOT NULL DEFAULT 0,
              review_weight REAL NOT NULL DEFAULT 1.0,
              added_at INTEGER NOT NULL,
              last_reviewed_at INTEGER,
              FOREIGN KEY(card_id) REFERENCES cards(id) ON DELETE CASCADE,
              FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE review_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              card_id TEXT NOT NULL,
              deck_id TEXT NOT NULL,
              mode TEXT NOT NULL,
              action TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX cards_deck_idx ON cards(deck_id, read_seen_count)',
          );
          await db.execute(
            'CREATE INDEX unknown_deck_idx ON unknown_cards(deck_id)',
          );
        },
      ),
    );
  }
}
