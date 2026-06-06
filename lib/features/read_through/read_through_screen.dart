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
            return Column(
              children: [
                _ReadProgressSlider(controller: controller),
                const Expanded(
                  child: Center(child: Text('Read-through completed.')),
                ),
              ],
            );
          }
          return Column(
            children: [
              _ReadProgressSlider(controller: controller),
              Expanded(
                child: Padding(
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadProgressSlider extends StatelessWidget {
  const _ReadProgressSlider({required this.controller});

  final ReadThroughController controller;

  @override
  Widget build(BuildContext context) {
    final readLabel = controller.totalCount == 0
        ? '0%'
        : '${controller.progressPercent}%';
    final positionLabel = controller.completed
        ? 'Complete'
        : 'Card ${controller.positionNumber}/${controller.totalCount}';
    final max = controller.totalCount == 0
        ? 1.0
        : controller.totalCount.toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Read progress',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                '$readLabel (${controller.readCount}/${controller.totalCount})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Slider(
            value: controller.seekValue,
            min: 0,
            max: max,
            divisions: controller.totalCount == 0
                ? null
                : controller.totalCount,
            label: positionLabel,
            onChanged: controller.totalCount == 0 ? null : controller.seekTo,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              positionLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}
