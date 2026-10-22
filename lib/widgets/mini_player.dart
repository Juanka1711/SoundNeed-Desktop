import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({
    required this.compact,
    required this.hasTrack,
    required this.title,
    required this.artist,
    required this.cover,
    this.artworkProvider,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.playerStateStream,
    required this.loading,
    required this.onTogglePlayback,
    required this.shuffleEnabled,
    required this.onToggleShuffle,
    required this.loopEnabled,
    required this.onToggleLoop,
    required this.onPrevious,
    required this.onNext,
    required this.position,
    required this.duration,
    required this.positionLabel,
    required this.durationLabel,
    required this.onSeek,
    required this.volume,
    required this.onVolumeChanged,
    required this.queueOpen,
    required this.onToggleQueue,
    required this.windowMaximized,
    required this.onToggleWindowSize,
    required this.panelColor,
    required this.accentColor,
    required this.mutedColor,
    super.key,
  });

  final bool compact;
  final bool hasTrack;
  final String title;
  final String artist;
  final Widget cover;
  final ImageProvider? artworkProvider;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final Stream<PlayerState> playerStateStream;
  final bool loading;
  final ValueChanged<bool> onTogglePlayback;
  final bool shuffleEnabled;
  final VoidCallback? onToggleShuffle;
  final bool loopEnabled;
  final VoidCallback onToggleLoop;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Duration position;
  final Duration? duration;
  final String positionLabel;
  final String durationLabel;
  final ValueChanged<Duration>? onSeek;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final bool queueOpen;
  final VoidCallback onToggleQueue;
  final bool windowMaximized;
  final VoidCallback onToggleWindowSize;
  final Color panelColor;
  final Color accentColor;
  final Color mutedColor;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  Color? _artworkColor;
  int _artworkRequestId = 0;

  void _showUnavailable(BuildContext context, String feature) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151522),
        title: Text('$feature no disponible'),
        content: Text('$feature todavía no está implementado en SoundNeed PC.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _readArtworkColor();
  }

  @override
  void didUpdateWidget(covariant MiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkProvider != widget.artworkProvider) {
      _readArtworkColor();
    }
  }

  Future<void> _readArtworkColor() async {
    final requestId = ++_artworkRequestId;
    final provider = widget.artworkProvider;
    if (provider == null) {
      if (_artworkColor != null && mounted) {
        setState(() => _artworkColor = null);
      }
      return;
    }
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: Brightness.dark,
      );
      if (mounted && requestId == _artworkRequestId) {
        setState(() => _artworkColor = scheme.primary);
      }
    } catch (_) {
      if (mounted && requestId == _artworkRequestId) {
        setState(() => _artworkColor = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrowWindow = MediaQuery.sizeOf(context).width < 700;
    final compact = widget.compact;
    final hasTrack = widget.hasTrack;
    final title = widget.title;
    final artist = widget.artist;
    final cover = widget.cover;
    final isFavorite = widget.isFavorite;
    final onToggleFavorite = widget.onToggleFavorite;
    final playerStateStream = widget.playerStateStream;
    final loading = widget.loading;
    final onTogglePlayback = widget.onTogglePlayback;
    final shuffleEnabled = widget.shuffleEnabled;
    final onToggleShuffle = widget.onToggleShuffle;
    final loopEnabled = widget.loopEnabled;
    final onToggleLoop = widget.onToggleLoop;
    final onPrevious = widget.onPrevious;
    final onNext = widget.onNext;
    final position = widget.position;
    final duration = widget.duration;
    final positionLabel = widget.positionLabel;
    final durationLabel = widget.durationLabel;
    final onSeek = widget.onSeek;
    final volume = widget.volume;
    final onVolumeChanged = widget.onVolumeChanged;
    final queueOpen = widget.queueOpen;
    final onToggleQueue = widget.onToggleQueue;
    final windowMaximized = widget.windowMaximized;
    final onToggleWindowSize = widget.onToggleWindowSize;
    final panelColor = widget.panelColor;
    final accentColor = widget.hasTrack
        ? _artworkColor ?? widget.accentColor
        : const Color(0xFF747484);
    final playButtonColor = widget.hasTrack
        ? accentColor
        : const Color(0xFF292936);
    final mutedColor = widget.mutedColor;
    const controlColor = Color(0xFFCACAD4);
    final darkArtworkColor = HSLColor.fromColor(accentColor)
        .withLightness(.075)
        .toColor();

    return Container(
      height: compact ? 66 : 78,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 12),
    decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accentColor.withValues(alpha: widget.hasTrack ? .20 : .035),
          Color.alphaBlend(darkArtworkColor.withValues(alpha: .34), panelColor),
          accentColor.withValues(alpha: widget.hasTrack ? .08 : .025),
        ],
        stops: const [0, .48, 1],
      ),
      border: Border.all(
        color: accentColor.withValues(alpha: widget.hasTrack ? .24 : .07),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: widget.hasTrack ? .12 : .02),
          blurRadius: 30,
          spreadRadius: -5,
          offset: const Offset(0, 9),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: .25),
          blurRadius: 20,
          spreadRadius: -5,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        SizedBox(
          width: narrowWindow ? 105 : (compact ? 180 : 300),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 38 : 50,
                height: compact ? 38 : 50,
                child: cover,
              ),
              SizedBox(width: compact ? 7 : 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: compact ? 8 : 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (onToggleFavorite != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Favorito',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 13,
                    color: isFavorite ? accentColor : mutedColor,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 24,
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onToggleShuffle != null)
                              IconButton(
                                tooltip: shuffleEnabled
                                    ? 'Desactivar aleatorio'
                                    : 'Reproducción aleatoria',
                                onPressed: onToggleShuffle,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  size: 19,
                                  color: shuffleEnabled
                                      ? accentColor
                                      : mutedColor,
                                ),
                              ),
                            IconButton(
                              tooltip: 'Anterior',
                              onPressed: onPrevious,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 7),
                            StreamBuilder<PlayerState>(
                              stream: playerStateStream,
                              builder: (context, snapshot) {
                                final playing = snapshot.data?.playing ?? false;
                                final totalMs = duration?.inMilliseconds ?? 0;
                                final progress = totalMs <= 0
                                    ? 0.0
                                    : (position.inMilliseconds / totalMs)
                                          .clamp(0.0, 1.0);
                                return SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 37,
                                        height: 37,
                                        child: CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 2,
                                          color: playButtonColor,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: .13),
                                        ),
                                      ),
                                      Material(
                                        color: playButtonColor,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          onTap: () =>
                                              onTogglePlayback(playing),
                                          customBorder: const CircleBorder(),
                                          child: SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: Center(
                                              child: loading
                                                  ? const SizedBox(
                                                      width: 17,
                                                      height: 17,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Color(
                                                              0xFF0B0B12,
                                                            ),
                                                          ),
                                                    )
                                                  : Icon(
                                                      !hasTrack
                                                          ? Icons.add
                                                          : playing
                                                          ? Icons.pause_rounded
                                                          : Icons
                                                                .play_arrow_rounded,
                                                      color: widget.hasTrack
                                                          ? const Color(
                                                              0xFF0B0B12,
                                                            )
                                                          : widget.accentColor,
                                                      size: 20,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 7),
                            IconButton(
                              tooltip: 'Siguiente',
                              onPressed: onNext,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: loopEnabled
                                  ? 'Desactivar bucle'
                                  : 'Activar bucle',
                              onPressed: onToggleLoop,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.repeat_rounded,
                                size: 19,
                                color: loopEnabled ? accentColor : mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact && !narrowWindow)
                Positioned(
                  left: constraints.maxWidth * .10,
                  right: constraints.maxWidth * .10,
                  bottom: 6,
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 30,
                      child: Text(
                        positionLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: mutedColor, fontSize: 9),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProgressTrack(
                        progress: duration == null || duration!.inMilliseconds <= 0
                            ? 0
                            : (position.inMilliseconds / duration!.inMilliseconds)
                                  .clamp(0.0, 1.0),
                        onSeek: onSeek == null || duration == null
                            ? null
                            : (value) => onSeek!(Duration(
                                  milliseconds:
                                      (duration!.inMilliseconds * value).round(),
                                )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: 30,
                      child: Text(
                        durationLabel,
                        textAlign: TextAlign.left,
                        style: TextStyle(color: mutedColor, fontSize: 9),
                      ),
                    ),
                  ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: narrowWindow ? 105 : (compact ? 180 : 300),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!narrowWindow) IconButton(
                tooltip: 'Letras',
                onPressed: () => _showUnavailable(context, 'Letras'),
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.lyrics_outlined, size: 22, color: controlColor),
              ),
              IconButton(
                tooltip: queueOpen ? 'Ocultar cola' : 'Ver cola',
                onPressed: onToggleQueue,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.queue_music,
                  size: 22,
                  color: queueOpen ? accentColor : controlColor,
                ),
              ),
              IconButton(
                tooltip: 'Dispositivo de reproducción',
                onPressed: () => _showUnavailable(context, 'Dispositivos'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.devices,
                  size: 24,
                  color: Color(0xFFE2E2EA),
                ),
              ),
              if (!compact && !narrowWindow) ...[
                Icon(Icons.volume_up_outlined, size: 22, color: controlColor),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: accentColor,
                      inactiveTrackColor: Colors.white.withValues(alpha: .17),
                      thumbColor: accentColor,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: volume,
                      onChanged: onVolumeChanged,
                    ),
                  ),
                ),
              ],
              if (!narrowWindow) IconButton(
                tooltip: windowMaximized
                    ? 'Restaurar ventana'
                    : 'Maximizar ventana',
                onPressed: onToggleWindowSize,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  windowMaximized
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  size: 22,
                  color: controlColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress, required this.onSeek});

  final double progress;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    void update(Offset localPosition, double width) {
      if (onSeek == null || width <= 0) return;
      onSeek!( (localPosition.dx / width).clamp(0.0, 1.0));
    }

    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onSeek == null
            ? null
            : (details) => update(details.localPosition, constraints.maxWidth),
        onHorizontalDragUpdate: onSeek == null
            ? null
            : (details) => update(details.localPosition, constraints.maxWidth),
        child: SizedBox(
          height: 16,
          child: CustomPaint(
            painter: _ProgressTrackPainter(progress),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ProgressTrackPainter extends CustomPainter {
  const _ProgressTrackPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final track = Paint()
      ..color = const Color(0xFF9292A5).withValues(alpha: .32)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = const Color(0xFF83E8FF)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), track);
    final activeX = size.width * progress.clamp(0.0, 1.0);
    canvas.drawLine(Offset(0, centerY), Offset(activeX, centerY), active);
    canvas.drawCircle(Offset(activeX, centerY), 5, active..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _ProgressTrackPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
