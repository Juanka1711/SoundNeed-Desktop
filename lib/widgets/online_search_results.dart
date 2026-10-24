import 'package:flutter/material.dart';

class OnlineSearchResult {
  const OnlineSearchResult({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.durationSeconds,
    this.rank,
  });

  final String videoId;
  final String title;
  final String artist;
  final String thumbnail;
  final int durationSeconds;
  final int? rank;
}

class OnlineSearchResults extends StatelessWidget {
  const OnlineSearchResults({
    required this.results,
    required this.playingVideoId,
    required this.isPlaying,
    required this.loadingVideoId,
    required this.onPlay,
    this.onAddToPlaylist,
    super.key,
  });

  final List<OnlineSearchResult> results;
  final String? playingVideoId;
  final bool isPlaying;
  final String? loadingVideoId;
  final ValueChanged<int> onPlay;

  /// Opcional: conectar después con el sistema real de playlists.
  final ValueChanged<int>? onAddToPlaylist;

  static const _cyan = Color(0xFF83E8FF);
  static const _muted = Color(0xFF9292A5);
  static const _line = Color(0xFF292932);

  String _time(int seconds) {
    final duration = Duration(seconds: seconds);
    return '${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.music_off_rounded, size: 42, color: _muted),
              SizedBox(height: 14),
              Text(
                'No encontramos canciones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Prueba con otro nombre o artista.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _featuredResult(context),
        if (results.length > 1) ...[
          const SizedBox(height: 34),
          const Row(
            children: [
              Text(
                'Más canciones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(
            results.length - 1,
            (index) => _resultRow(context, index + 1),
          ),
        ],
      ],
    );
  }

  Widget _featuredResult(BuildContext context) {
    final result = results.first;
    final selected = playingVideoId == result.videoId;
    final loading = loadingVideoId == result.videoId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 164,
                height: 164,
                child: Image.network(
                  result.thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _thumbnailFallback(),
                ),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    result.artist,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _circleButton(
                        tooltip: selected && isPlaying
                            ? 'En reproducción'
                            : 'Reproducir',
                        icon: loading
                            ? null
                            : selected && isPlaying
                            ? Icons.equalizer_rounded
                            : Icons.play_arrow_rounded,
                        primary: true,
                        onPressed: loading ? null : () => onPlay(0),
                        loading: loading,
                      ),
                      _circleButton(
                        tooltip: 'Agregar a playlist',
                        icon: Icons.add_rounded,
                        onPressed: () => _addToPlaylist(context, 0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 1, color: _line),
      ],
    );
  }

  Widget _resultRow(BuildContext context, int index) {
    final result = results[index];
    final selected = playingVideoId == result.videoId;
    final loading = loadingVideoId == result.videoId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}'.padLeft(2, '0'),
              style: TextStyle(
                color: selected ? _cyan : _muted,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 92,
              height: 66,
              child: Image.network(
                result.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _thumbnailFallback(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: loading ? null : () => onPlay(index),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? _cyan : Colors.white,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      result.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (result.durationSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                _time(result.durationSeconds),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          _circleButton(
            tooltip: 'Agregar a playlist',
            icon: Icons.add_rounded,
            onPressed: () => _addToPlaylist(context, index),
          ),
          const SizedBox(width: 4),
          _circleButton(
            tooltip: loading
                ? 'Cargando canción'
                : selected && isPlaying
                ? 'En reproducción'
                : 'Reproducir',
            icon: loading
                ? null
                : selected && isPlaying
                ? Icons.equalizer_rounded
                : Icons.play_arrow_rounded,
            loading: loading,
            onPressed: loading ? null : () => onPlay(index),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required String tooltip,
    required IconData? icon,
    required VoidCallback? onPressed,
    bool primary = false,
    bool loading = false,
  }) {
    return Semantics(
      label: tooltip,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: primary ? _cyan : Colors.white.withValues(alpha: 0.055),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: primary ? 44 : 36,
              height: primary ? 44 : 36,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _cyan,
                        ),
                      )
                    : Icon(
                        icon,
                        size: primary ? 24 : 18,
                        color: primary ? const Color(0xFF0B0B12) : Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnailFallback() {
    return Container(
      color: const Color(0xFF151522),
      alignment: Alignment.center,
      child: const Icon(Icons.music_note_rounded, color: _cyan, size: 28),
    );
  }

  void _addToPlaylist(BuildContext context, int index) {
    if (onAddToPlaylist != null) {
      onAddToPlaylist!(index);
      return;
    }

    // Simulación temporal: no guarda la canción realmente.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Agregar a playlist estará disponible pronto.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF20202B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}
