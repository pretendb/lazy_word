import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';

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
  static final _soundTag = RegExp(r'\[sound:[^\]]+\]', caseSensitive: false);

  final _player = AudioPlayer();
  double _drag = 0;
  String? _playingPath;
  String? _audioError;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(AudioAttachment attachment) async {
    if (!await File(attachment.localPath).exists()) {
      setState(() => _audioError = 'Audio file is missing.');
      return;
    }
    try {
      await _player.stop();
      await _player.setFilePath(attachment.localPath);
      if (!mounted) return;
      setState(() {
        _playingPath = attachment.localPath;
        _audioError = null;
      });
      await _player.play();
    } catch (_) {
      if (mounted) setState(() => _audioError = 'Could not play this audio.');
    } finally {
      if (mounted) setState(() => _playingPath = null);
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      setState(() => _drag -= notification.overscroll);
    } else if (notification is ScrollEndNotification && _drag != 0) {
      if (_drag < -60) widget.onKnown();
      if (_drag > 60) widget.onUnknown();
      if (mounted) setState(() => _drag = 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: Transform.translate(
        offset: Offset(0, _drag.clamp(-100, 100)),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 5,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              children: [
                _RichCardSide(
                  html: widget.card.frontHtml,
                  fallback: widget.card.front,
                  images: widget.card.images,
                  prominent: true,
                ),
                const Divider(height: 44),
                _RichCardSide(
                  html: widget.card.backHtml,
                  fallback: widget.card.back,
                  images: widget.card.images,
                ),
                if (widget.card.audio.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final attachment in widget.card.audio)
                        FilledButton.tonalIcon(
                          onPressed: _playingPath == attachment.localPath
                              ? null
                              : () => _play(attachment),
                          icon: const Icon(Icons.volume_up_outlined),
                          label: Text(
                            widget.card.audio.length == 1
                                ? 'Play Pronunciation'
                                : attachment.filename,
                          ),
                        ),
                    ],
                  ),
                ],
                if (_audioError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _audioError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RichCardSide extends StatelessWidget {
  const _RichCardSide({
    required this.html,
    required this.fallback,
    required this.images,
    this.prominent = false,
  });

  final String? html;
  final String fallback;
  final List<ImageAttachment> images;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final richContent = html?.replaceAll(_SwipeCardViewState._soundTag, '');
    if (richContent == null || richContent.trim().isEmpty) {
      return Text(
        fallback,
        textAlign: TextAlign.center,
        style: prominent
            ? Theme.of(context).textTheme.headlineMedium
            : Theme.of(context).textTheme.titleLarge,
      );
    }
    final imagePaths = {
      for (final image in images) image.filename: image.localPath,
    };
    return Html(
      data: richContent,
      shrinkWrap: true,
      onLinkTap: (_, _, _) {},
      extensions: [
        TagExtension(
          tagsToExtend: const {'img'},
          builder: (extensionContext) {
            final source = extensionContext.attributes['src'];
            final path = source == null ? null : imagePaths[source];
            if (path == null) {
              return Text(extensionContext.attributes['alt'] ?? '');
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    Text(extensionContext.attributes['alt'] ?? 'Missing image'),
              ),
            );
          },
        ),
      ],
      style: {
        'body': Style(
          margin: Margins.zero,
          textAlign: TextAlign.center,
          fontSize: FontSize(prominent ? 24 : 19),
        ),
      },
    );
  }
}
