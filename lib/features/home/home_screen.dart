import 'package:flutter/material.dart';

import '../../data/card_dao.dart';
import '../../data/unknown_card_dao.dart';
import '../../domain/deck.dart';
import '../import_deck/import_deck_controller.dart';
import '../read_through/read_through_screen.dart';
import '../unknown_review/unknown_review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.deck,
    required this.cardDao,
    required this.unknownCardDao,
    required this.importController,
    required this.onDeckReplaced,
  });

  final Deck deck;
  final CardDao cardDao;
  final UnknownCardDao unknownCardDao;
  final ImportDeckController importController;
  final ValueChanged<Deck> onDeckReplaced;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _unknownCount;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deck.id != widget.deck.id) {
      _unknownCount = null;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final count = await widget.cardDao.unknownCount(widget.deck.id);
    if (mounted) setState(() => _unknownCount = count);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _refresh();
  }

  Future<void> _replaceDeck() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace current deck?'),
        content: const Text(
          'This clears the current deck, unknown list, and all review progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose New .apkg'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deck = await widget.importController.chooseAndImport();
    if (deck != null) widget.onDeckReplaced(deck);
    if (mounted && widget.importController.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.importController.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lazy Word')),
      body: AnimatedBuilder(
        animation: widget.importController,
        builder: (context, child) => Column(
          children: [
            if (widget.importController.isImporting)
              const LinearProgressIndicator(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        widget.deck.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(widget.deck.sourceFileName),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Cards',
                              value: '${widget.deck.cardCount}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Unknown',
                              value: _unknownCount?.toString() ?? '...',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: widget.importController.isImporting
                            ? null
                            : () => _open(
                                ReadThroughScreen(
                                  cardDao: widget.cardDao,
                                  deckId: widget.deck.id,
                                ),
                              ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Read-through Mode'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: widget.importController.isImporting
                            ? null
                            : () => _open(
                                UnknownReviewScreen(
                                  unknownCardDao: widget.unknownCardDao,
                                  deckId: widget.deck.id,
                                ),
                              ),
                        icon: const Icon(Icons.replay),
                        label: const Text('Unknown Review Mode'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: widget.importController.isImporting
                            ? null
                            : _replaceDeck,
                        icon: widget.importController.isImporting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.folder_open),
                        label: const Text('Choose New .apkg'),
                      ),
                      if (widget.importController.progress.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          widget.importController.progress,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    );
  }
}
