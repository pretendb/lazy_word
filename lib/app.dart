import 'package:flutter/material.dart';

import 'core/app_paths.dart';
import 'data/card_dao.dart';
import 'data/deck_dao.dart';
import 'data/local_db.dart';
import 'data/unknown_card_dao.dart';
import 'domain/deck.dart';
import 'features/home/home_screen.dart';
import 'features/import_deck/import_deck_controller.dart';
import 'features/import_deck/import_deck_screen.dart';
import 'import/apkg_importer.dart';

class LazyWordApp extends StatefulWidget {
  const LazyWordApp({super.key});

  @override
  State<LazyWordApp> createState() => _LazyWordAppState();
}

class _LazyWordAppState extends State<LazyWordApp> {
  final _paths = AppPaths();
  final _localDb = LocalDb();
  late final DeckDao _deckDao = DeckDao(_localDb);
  late final CardDao _cardDao = CardDao(_localDb);
  late final UnknownCardDao _unknownCardDao = UnknownCardDao(_localDb);
  late final ImportDeckController _importController = ImportDeckController(
    ApkgImporter(_paths, _deckDao),
  );

  Deck? _deck;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentDeck();
  }

  Future<void> _loadCurrentDeck() async {
    final id = await _paths.readCurrentDeckId();
    final deck = id == null ? null : await _deckDao.findById(id);
    if (!mounted) return;
    setState(() {
      _deck = deck;
      _loading = false;
    });
  }

  void _setDeck(Deck deck) {
    setState(() => _deck = deck);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lazy Word',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315c4b)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff7f5ef),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _deck == null
          ? ImportDeckScreen(
              controller: _importController,
              onImported: _setDeck,
            )
          : HomeScreen(
              deck: _deck!,
              cardDao: _cardDao,
              unknownCardDao: _unknownCardDao,
              importController: _importController,
              onDeckReplaced: _setDeck,
            ),
    );
  }
}
