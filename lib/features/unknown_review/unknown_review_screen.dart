import 'package:flutter/material.dart';

import '../../data/unknown_card_dao.dart';
import '../read_through/swipe_card_view.dart';
import 'unknown_review_controller.dart';

class UnknownReviewScreen extends StatefulWidget {
  const UnknownReviewScreen({
    super.key,
    required this.unknownCardDao,
    required this.deckId,
  });

  final UnknownCardDao unknownCardDao;
  final String deckId;

  @override
  State<UnknownReviewScreen> createState() => _UnknownReviewScreenState();
}

class _UnknownReviewScreenState extends State<UnknownReviewScreen> {
  late final UnknownReviewController controller;

  @override
  void initState() {
    super.initState();
    controller = UnknownReviewController(widget.unknownCardDao, widget.deckId)
      ..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unknown Review Mode')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final card = controller.currentCard;
          if (card == null) {
            return const Center(child: Text('Your unknown list is empty.'));
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Swipe up = known once (3 removes it)\n'
                  'Swipe down = still unknown, appears more often',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SwipeCardView(
                    key: ValueKey(
                      '${card.id}-${controller.currentUnknown?.knownStreak}',
                    ),
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
