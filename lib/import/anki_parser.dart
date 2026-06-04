import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../domain/flash_card.dart';
import 'html_cleaner.dart';

class AnkiParser {
  static final _conditionalPattern = RegExp(
    r'{{([#^])([^}]+)}}([\s\S]*?){{/\2}}',
  );
  static final _fieldPattern = RegExp(r'{{([^{}]+)}}');
  static final _clozePattern = RegExp(
    r'{{c(\d+)::([\s\S]*?)(?:::([\s\S]*?))?}}',
    caseSensitive: false,
  );
  static final _soundPattern = RegExp(
    r'\[sound:([^\]]+)\]',
    caseSensitive: false,
  );
  static final _imageAltPattern = RegExp(
    r'''<img\b[^>]*\balt=["']([^"']*)["'][^>]*>''',
    caseSensitive: false,
  );
  static final _imageSourcePattern = RegExp(
    r'''<img\b[^>]*\bsrc=["']([^"']*)["'][^>]*>''',
    caseSensitive: false,
  );

  Future<List<FlashCard>> parse(
    String databasePath,
    String deckId, {
    Map<String, String> mediaPaths = const {},
  }) async {
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
      final modelRows = await database.rawQuery(
        'SELECT models FROM col LIMIT 1',
      );
      final models = _parseModels(
        modelRows.isEmpty ? null : modelRows.first['models'] as String?,
      );
      final rows = await database.rawQuery('''
        SELECT c.id AS card_id, c.ord AS template_ordinal,
               n.id AS note_id, n.mid AS model_id, n.flds AS fields
        FROM cards c
        INNER JOIN notes n ON n.id = c.nid
        ORDER BY c.id
      ''');
      final now = DateTime.now().millisecondsSinceEpoch;
      final cards = <FlashCard>[];
      for (final row in rows) {
        final rawFields = row['fields'] as String? ?? '';
        final fields = rawFields.split('\u001f');
        final model = models['${row['model_id']}'];
        final rendered = _renderCard(
          model,
          fields,
          (row['template_ordinal'] as num?)?.toInt() ?? 0,
        );
        final front = HtmlCleaner.clean(_renderMediaAsText(rendered.$1));
        final back = HtmlCleaner.clean(_renderMediaAsText(rendered.$2));
        if (front.isEmpty || back.isEmpty) continue;
        final css = model?['css'] as String? ?? '';
        final frontHtml = _withCss(rendered.$1, css);
        final backHtml = _withCss(rendered.$2, css);
        final noteId = '${row['note_id']}';
        final cardId = '${row['card_id']}';
        final images = _imageAttachments('$frontHtml $backHtml', mediaPaths);
        final audio = _audioAttachments('$frontHtml $backHtml', mediaPaths);
        final isCloze = (model?['type'] as num?)?.toInt() == 1;
        cards.add(
          FlashCard(
            id: stableCardId(deckId, noteId, cardId, front, back),
            deckId: deckId,
            ankiNoteId: noteId,
            ankiCardId: cardId,
            front: front,
            back: back,
            frontHtml: frontHtml,
            backHtml: backHtml,
            images: images,
            audio: audio,
            type: _cardType(isCloze, images.isNotEmpty, audio.isNotEmpty),
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

  static Map<String, Map<String, dynamic>> _parseModels(String? rawModels) {
    if (rawModels == null || rawModels.isEmpty) return const {};
    final decoded = jsonDecode(rawModels) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
    );
  }

  static (String, String) _renderCard(
    Map<String, dynamic>? model,
    List<String> values,
    int templateOrdinal,
  ) {
    if (model == null) {
      return (
        values.isEmpty ? '' : values.first,
        values.length < 2 ? '' : values[1],
      );
    }

    final fields = <String, String>{};
    for (final field in (model['flds'] as List<dynamic>? ?? const [])) {
      final definition = Map<String, dynamic>.from(field as Map);
      final ordinal = (definition['ord'] as num?)?.toInt() ?? fields.length;
      final name = definition['name'] as String? ?? '';
      if (name.isNotEmpty && ordinal < values.length) {
        fields[name] = values[ordinal];
      }
    }

    final templates = model['tmpls'] as List<dynamic>? ?? const [];
    if (templates.isEmpty) {
      return (
        values.isEmpty ? '' : values.first,
        values.length < 2 ? '' : values[1],
      );
    }
    final template = Map<String, dynamic>.from(
      templates[templateOrdinal < templates.length ? templateOrdinal : 0]
          as Map,
    );
    final isCloze = (model['type'] as num?)?.toInt() == 1;
    final front = _renderTemplate(
      template['qfmt'] as String? ?? '',
      fields,
      templateOrdinal + 1,
      isCloze: isCloze,
      answerSide: false,
    );
    final back = _renderTemplate(
      template['afmt'] as String? ?? '',
      fields,
      templateOrdinal + 1,
      isCloze: isCloze,
      answerSide: true,
    );
    return (front, back);
  }

  static String _renderTemplate(
    String template,
    Map<String, String> fields,
    int clozeOrdinal, {
    required bool isCloze,
    required bool answerSide,
    String frontSide = '',
  }) {
    var rendered = template.replaceAll('{{FrontSide}}', frontSide);
    while (_conditionalPattern.hasMatch(rendered)) {
      rendered = rendered.replaceAllMapped(_conditionalPattern, (match) {
        final value = fields[match.group(2)!.trim()] ?? '';
        final include = match.group(1) == '#'
            ? value.isNotEmpty
            : value.isEmpty;
        return include ? match.group(3)! : '';
      });
    }
    rendered = rendered.replaceAllMapped(_fieldPattern, (match) {
      final expression = match.group(1)!.trim();
      final separator = expression.indexOf(':');
      final filter = separator < 0 ? '' : expression.substring(0, separator);
      final name = separator < 0
          ? expression
          : expression.substring(separator + 1);
      final value = fields[name] ?? '';
      if (isCloze && filter == 'cloze') {
        return _renderCloze(value, clozeOrdinal, answerSide);
      }
      return value;
    });
    return rendered;
  }

  static String _renderCloze(String value, int ordinal, bool answerSide) {
    return value.replaceAllMapped(_clozePattern, (match) {
      if (int.tryParse(match.group(1)!) != ordinal) return match.group(2)!;
      if (answerSide) return match.group(2)!;
      final hint = match.group(3);
      return hint == null || hint.isEmpty ? '[...]' : '[$hint]';
    });
  }

  static String _renderMediaAsText(String value) {
    return value
        .replaceAllMapped(_soundPattern, (match) => ' ${match.group(1)} ')
        .replaceAllMapped(_imageAltPattern, (match) => ' ${match.group(1)} ')
        .replaceAllMapped(
          _imageSourcePattern,
          (match) => ' ${match.group(1)} ',
        );
  }

  static List<ImageAttachment> _imageAttachments(
    String html,
    Map<String, String> mediaPaths,
  ) {
    final seen = <String>{};
    return _imageSourcePattern
        .allMatches(html)
        .map((match) => match.group(1)!)
        .where(
          (filename) => seen.add(filename) && mediaPaths.containsKey(filename),
        )
        .map(
          (filename) => ImageAttachment(
            filename: filename,
            localPath: mediaPaths[filename]!,
          ),
        )
        .toList();
  }

  static List<AudioAttachment> _audioAttachments(
    String html,
    Map<String, String> mediaPaths,
  ) {
    final seen = <String>{};
    return _soundPattern
        .allMatches(html)
        .map((match) => match.group(1)!)
        .where(
          (filename) => seen.add(filename) && mediaPaths.containsKey(filename),
        )
        .map(
          (filename) => AudioAttachment(
            filename: filename,
            localPath: mediaPaths[filename]!,
          ),
        )
        .toList();
  }

  static CardType _cardType(bool cloze, bool image, bool audio) {
    if (cloze) return CardType.cloze;
    if (image && audio) return CardType.mixed;
    if (image) return CardType.image;
    if (audio) return CardType.audio;
    return CardType.basic;
  }

  static String _withCss(String html, String css) {
    return css.trim().isEmpty ? html : '<style>$css</style>$html';
  }
}
