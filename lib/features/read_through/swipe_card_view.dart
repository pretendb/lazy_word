import 'package:flutter/material.dart';

import '../../domain/flash_card.dart';

class SwipeCardView extends StatefulWidget {
  const SwipeCardView({
    super.key,
    required this.card,
    required this.onKnown,
    required this.onUnknown,
  });

  final FlashCard card;
  final VoidCallback onKnown;
  final VoidCallback onUnknown;

  @override
  State<SwipeCardView> createState() => _SwipeCardViewState();
}

class _SwipeCardViewState extends State<SwipeCardView> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) =>
          setState(() => _drag += details.delta.dy),
      onVerticalDragEnd: (_) {
        if (_drag < -60) widget.onKnown();
        if (_drag > 60) widget.onUnknown();
        setState(() => _drag = 0);
      },
      child: Transform.translate(
        offset: Offset(0, _drag.clamp(-100, 100)),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.card.front,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Divider(height: 48),
                Text(
                  widget.card.back,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
