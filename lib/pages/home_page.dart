import 'package:flutter/material.dart';

import '../widgets/library_content.dart';
import '../widgets/middle_content_panel.dart';
import '../widgets/online_search_results.dart';

class HomeOnlineSection {
  const HomeOnlineSection({
    required this.title,
    required this.subtitle,
    required this.results,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onPlay,
  });

  final String title;
  final String subtitle;
  final List<OnlineSearchResult> results;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<int> onPlay;
}

class HomePage extends StatelessWidget {
  const HomePage({
    required this.config,
    required this.colombiaChart,
    required this.worldChart,
    required this.discoverMusic,
    required this.podcastSuggestions,
    required this.playingVideoId,
    required this.isPlaying,
    required this.loadingVideoId,
    required this.continueTitle,
    required this.continueArtist,
    required this.onContinue,
    required this.stationArtists,
    required this.onSurpriseMix,
    required this.onPlayStation,
    required this.onNavigate,
    super.key,
  });

  final LibraryPageConfig config;
  final HomeOnlineSection colombiaChart;
  final HomeOnlineSection worldChart;
  final HomeOnlineSection discoverMusic;
  final HomeOnlineSection podcastSuggestions;
  final String? playingVideoId;
  final bool isPlaying;
  final String? loadingVideoId;
  final String? continueTitle;
  final String? continueArtist;
  final VoidCallback? onContinue;
  final List<String> stationArtists;
  final VoidCallback onSurpriseMix;
  final ValueChanged<String> onPlayStation;
  final ValueChanged<String> onNavigate;

  static const _accent = Color(0xFF83E8FF);
  static const _muted = Color(0xFF9292A5);

  @override
  Widget build(BuildContext context) => MiddleContentPanel(
    section: 'Inicio',
    config: config,
    showHeader: false,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _welcomeHeader(),
        const SizedBox(height: 22),
        _quickSections(),
        const SizedBox(height: 26),
        _surpriseMixCard(),
        if (onContinue != null) ...[
          const SizedBox(height: 26),
          _continueListeningCard(),
        ],
        const SizedBox(height: 30),
        _onlineSection(colombiaChart),
        const SizedBox(height: 26),
        _onlineSection(discoverMusic),
        const SizedBox(height: 26),
        _onlineSection(worldChart),
        const SizedBox(height: 26),
        _onlineSection(podcastSuggestions),
        if (stationArtists.isNotEmpty) ...[
          const SizedBox(height: 30),
          _recommendedStations(),
        ],
        if (config.trackCount > 0) ...[
          const SizedBox(height: 34),
          const Text(
            'TU BIBLIOTECA',
            style: TextStyle(
              color: _accent,
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
        ],
        config.body,
      ],
    ),
  );

  Widget _welcomeHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 19
        ? 'Buenas tardes'
        : 'Buenas noches';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TU SONIDO · HOY',
          style: TextStyle(
            color: _accent,
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '$greeting 👋',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          config.trackCount == 0
              ? 'Tu próximo descubrimiento empieza aquí.'
              : '${config.trackCount} canciones listas para acompañarte.',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _quickSections() {
    const actions = <(String, IconData)>[
      ('Tu música', Icons.library_music_rounded),
      ('Favoritos', Icons.favorite_rounded),
      ('Playlists', Icons.queue_music_rounded),
    ];

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(
            child: _quickSectionCard(
              actions[index].$1,
              actions[index].$2,
              () => onNavigate(actions[index].$1),
            ),
          ),
        ],
      ],
    );
  }

  Widget _quickSectionCard(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: .035),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: _accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surpriseMixCard() => Material(
    color: Colors.white.withValues(alpha: .045),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onSurpriseMix,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.shuffle_rounded, color: _accent),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mezcla sorpresa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Una selección aleatoria de tu biblioteca',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.play_circle_fill_rounded,
              color: _accent,
              size: 30,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _continueListeningCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Continuar escuchando', 'Vuelve a tu reproducción actual'),
      const SizedBox(height: 12),
      Material(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onContinue,
          leading: const Icon(Icons.graphic_eq_rounded, color: _accent),
          title: Text(
            continueTitle ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            continueArtist ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted),
          ),
          trailing: const Icon(Icons.play_arrow_rounded, color: _accent),
        ),
      ),
    ],
  );

  Widget _onlineSection(HomeOnlineSection section) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(section.title, section.subtitle, onRefresh: section.onRefresh),
      const SizedBox(height: 14),
      if (section.loading)
        const SizedBox(
          height: 168,
          child: Center(child: CircularProgressIndicator(color: _accent)),
        )
      else if (section.error != null)
        SizedBox(
          height: 112,
          child: Center(
            child: TextButton.icon(
              onPressed: section.onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(section.error!),
            ),
          ),
        )
      else if (section.results.isEmpty)
        const SizedBox(
          height: 112,
          child: Center(
            child: Text(
              'Todavía no hay resultados para mostrar.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ),
        )
      else
        SizedBox(
          height: 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.results.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _onlineCard(section, index),
          ),
        ),
    ],
  );

  Widget _onlineCard(HomeOnlineSection section, int index) {
    final result = section.results[index];
    final selected = result.videoId == playingVideoId;
    final loading = result.videoId == loadingVideoId;

    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    result.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.white.withValues(alpha: .06),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: _muted,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: Material(
                    color: _accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: loading ? null : () => section.onPlay(index),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                          child: loading
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(
                                  selected && isPlaying
                                      ? Icons.equalizer_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 21,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            result.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _recommendedStations() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Estaciones por artista', 'Basadas en tu biblioteca local'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: stationArtists
            .map(
              (artist) => ActionChip(
                avatar: const Icon(Icons.radio_rounded, size: 17),
                label: Text(artist),
                onPressed: () => onPlayStation(artist),
              ),
            )
            .toList(growable: false),
      ),
    ],
  );

  Widget _heading(String title, String subtitle, {VoidCallback? onRefresh}) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              tooltip: 'Actualizar',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: _muted),
            ),
        ],
      );
}
