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

  AudioPlayer? _player;
  Process? _linuxAudioProcess;
  double _drag = 0;
  String? _playingPath;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    if (!Platform.isLinux) {
      _player = AudioPlayer();
    }
  }

  @override
  void dispose() {
    _linuxAudioProcess?.kill();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _play(AudioAttachment attachment) async {
    if (!await File(attachment.localPath).exists()) {
      setState(() => _audioError = 'Audio file is missing.');
      return;
    }
    try {
      setState(() {
        _playingPath = attachment.localPath;
        _audioError = null;
      });
      if (Platform.isLinux) {
        await _playWithLinuxProcess(attachment.localPath);
        return;
      }
      final player = _player;
      if (player == null) throw StateError('Audio player is not available.');
      await player.stop();
      await player.setFilePath(attachment.localPath);
      if (!mounted) return;
      await player.play();
    } catch (_) {
      if (mounted) setState(() => _audioError = 'Could not play this audio.');
    } finally {
      if (mounted) setState(() => _playingPath = null);
    }
  }

  Future<void> _playWithLinuxProcess(String path) async {
    _linuxAudioProcess?.kill();
    _linuxAudioProcess = await Process.start('ffplay', [
      '-nodisp',
      '-autoexit',
      '-loglevel',
      'quiet',
      path,
    ]);
    final exitCode = await _linuxAudioProcess!.exitCode;
    if (exitCode != 0) {
      throw const ProcessException('ffplay', [], 'Playback failed');
    }
  }

  void _handleDragEnd() {
    if (_drag < -60) widget.onKnown();
    if (_drag > 60) widget.onUnknown();
    if (mounted) setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.clamp(280.0, 680.0).toDouble();
        final maxHeight = constraints.maxHeight.clamp(260.0, 760.0).toDouble();
        final horizontalPadding = maxWidth < 420 ? 14.0 : 20.0;
        final verticalPadding = maxHeight < 520 ? 14.0 : 18.0;
        final contentWidth = maxWidth - (horizontalPadding * 2);
        final imageMaxHeight = (maxHeight * 0.28).clamp(90.0, 210.0).toDouble();
        final backAlreadyIncludesFront = _includesFront(
          frontHtml: widget.card.frontHtml,
          backHtml: widget.card.backHtml,
          frontFallback: widget.card.front,
          backFallback: widget.card.back,
        );

        return Center(
          child: SizedBox(
            width: maxWidth,
            height: maxHeight,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() => _drag += details.delta.dy);
              },
              onVerticalDragEnd: (_) => _handleDragEnd(),
              child: Transform.translate(
                offset: Offset(0, _drag.clamp(-80, 80)),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 5,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!backAlreadyIncludesFront) ...[
                                _RichCardSide(
                                  html: widget.card.frontHtml,
                                  fallback: widget.card.front,
                                  images: widget.card.images,
                                  imageMaxHeight: imageMaxHeight,
                                  prominent: true,
                                ),
                                const SizedBox(height: 10),
                              ],
                              _RichCardSide(
                                html: widget.card.backHtml,
                                fallback: widget.card.back,
                                images: widget.card.images,
                                imageMaxHeight: imageMaxHeight,
                                prominent: backAlreadyIncludesFront,
                              ),
                              if (widget.card.audio.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final attachment in widget.card.audio)
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed:
                                            _playingPath == attachment.localPath
                                            ? null
                                            : () => _play(attachment),
                                        icon: const Icon(
                                          Icons.volume_up_outlined,
                                          size: 18,
                                        ),
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
                                const SizedBox(height: 6),
                                Text(
                                  _audioError!,
                                  textAlign: TextAlign.center,
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _includesFront({
    required String? frontHtml,
    required String? backHtml,
    required String frontFallback,
    required String backFallback,
  }) {
    final frontText = _plainText(frontHtml ?? frontFallback);
    final backText = _plainText(backHtml ?? backFallback);
    return frontText.isNotEmpty &&
        backText != frontText &&
        backText.startsWith(frontText);
  }

  String _plainText(String value) {
    return value
        .replaceAll(_soundTag, ' ')
        .replaceAll(
          RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _RichCardSide extends StatelessWidget {
  const _RichCardSide({
    required this.html,
    required this.fallback,
    required this.images,
    required this.imageMaxHeight,
    this.prominent = false,
  });

  final String? html;
  final String fallback;
  final List<ImageAttachment> images;
  final double imageMaxHeight;
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
              constraints: BoxConstraints(maxHeight: imageMaxHeight),
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
          fontSize: FontSize(prominent ? 21 : 17),
          lineHeight: const LineHeight(1.18),
        ),
        'p': Style(margin: Margins.only(bottom: 6)),
        'div': Style(margin: Margins.only(bottom: 4)),
      },
    );
  }
}
