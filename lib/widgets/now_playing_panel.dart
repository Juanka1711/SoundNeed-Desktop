import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({
    required this.title,
    required this.artist,
    required this.artwork,
    required this.hasTrack,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.playerStateStream,
    required this.position,
    required this.duration,
    required this.positionLabel,
    required this.durationLabel,
    required this.onSeek,
    required this.onTogglePlayback,
    required this.onPrevious,
    required this.onNext,
    required this.volume,
    required this.onVolumeChanged,
    required this.queueOpen,
    required this.onToggleQueue,
    super.key,
  });

  final String title;
  final String artist;
  final Widget artwork;
  final bool hasTrack;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final Stream<PlayerState> playerStateStream;
  final Duration position;
  final Duration? duration;
  final String positionLabel;
  final String durationLabel;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<bool> onTogglePlayback;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final bool queueOpen;
  final VoidCallback onToggleQueue;

  static const _panel = Color(0xFF0B0B0E);
  static const _raised = Color(0xFF29292F);
  static const _accent = Color(0xFF83E8FF);
  static const _muted = Color(0xFF9292A5);

  @override
  Widget build(BuildContext context) {
    final totalMs = duration?.inMilliseconds ?? 0;
    final progress = totalMs <= 0
        ? 0.0
        : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 34, 18, 18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _raised),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'REPRODUCIENDO',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Ver cola',
                onPressed: onToggleQueue,
                icon: Icon(
                  queueOpen
                      ? Icons.queue_music
                      : Icons.queue_music_outlined,
                  color: queueOpen ? _accent : _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(width: 246, height: 246, child: artwork),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onToggleFavorite != null)
                IconButton(
                  tooltip: isFavorite
                      ? 'Quitar de favoritos'
                      : 'Añadir a favoritos',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? _accent : _muted,
                  ),
                ),
            ],
          ),
          Slider(
            value: progress,
            onChanged: onSeek == null || duration == null
                ? null
                : (value) => onSeek!(Duration(
                    milliseconds: (totalMs * value).round(),
                  )),
            activeColor: _accent,
            inactiveColor: _raised,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  positionLabel,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                Text(
                  durationLabel,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous_rounded, size: 30),
              ),
              const SizedBox(width: 12),
              StreamBuilder<PlayerState>(
                stream: playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.black,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(15),
                    ),
                    onPressed: () => onTogglePlayback(playing),
                    child: Icon(
                      !hasTrack
                          ? Icons.add
                          : playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.skip_next_rounded, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, color: _muted, size: 19),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: onVolumeChanged,
                  activeColor: _accent,
                  inactiveColor: _raised,
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: _muted, size: 19),
            ],
          ),
          ],
        ),
      ),
    );
  }
}
