import 'package:flutter/material.dart';

import '../../domain/deck.dart';
import 'import_deck_controller.dart';

class ImportDeckScreen extends StatelessWidget {
  const ImportDeckScreen({
    super.key,
    required this.controller,
    required this.onImported,
  });

  final ImportDeckController controller;
  final ValueChanged<Deck> onImported;

  Future<void> _import() async {
    final deck = await controller.chooseAndImport();
    if (deck != null) onImported(deck);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Anki Deck')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.style_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choose a downloaded .apkg file to begin.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your deck and progress stay on this device.',
                    textAlign: TextAlign.center,
                  ),
                  if (controller.progress.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(controller.progress),
                  ],
                  if (controller.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      controller.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: controller.isImporting ? null : _import,
                    icon: controller.isImporting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open),
                    label: const Text('Choose .apkg File'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
