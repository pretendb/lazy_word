import 'package:flutter/material.dart';

import '../../data/card_dao.dart';
import 'read_through_controller.dart';
import 'swipe_card_view.dart';

class ReadThroughScreen extends StatefulWidget {
  const ReadThroughScreen({
    super.key,
    required this.cardDao,
    required this.deckId,
  });

  final CardDao cardDao;
  final String deckId;

  @override
  State<ReadThroughScreen> createState() => _ReadThroughScreenState();
}

class _ReadThroughScreenState extends State<ReadThroughScreen> {
  late final ReadThroughController controller;

  @override
  void initState() {
    super.initState();
    controller = ReadThroughController(widget.cardDao, widget.deckId)..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Read-through Mode')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final card = controller.current;
          if (card == null) {
            return const Center(child: Text('Read-through completed.'));
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Swipe up = known  •  Swipe down = add to unknown list',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SwipeCardView(
                    key: ValueKey(card.id),
                    card: card,
                    onKnown: () => controller.swipe(known: true),
                    onUnknown: () => controller.swipe(known: false),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
