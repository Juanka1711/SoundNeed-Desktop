import 'package:flutter/material.dart';

import '../services/home_discovery_service.dart';

class HomePodcastSection extends StatefulWidget {
  const HomePodcastSection({required this.onPlay, super.key});

  final ValueChanged<HomePodcastPlayRequest> onPlay;

  @override
  State<HomePodcastSection> createState() => _HomePodcastSectionState();
}

class _HomePodcastSectionState extends State<HomePodcastSection> {
  static const _surface = Color(0xFF191919);
  static const _muted = Color(0xFF969696);
  final _search = TextEditingController();
  List<HomePodcastShow> _recommendations = const [];
  List<HomePodcastShow> _results = const [];
  List<HomePodcastEpisode> _episodes = const [];
  HomePodcastShow? _selectedShow;
  bool _loading = true;
  bool _searching = false;
  bool _loadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations({bool refresh = false}) async {
    setState(() => _loading = true);
    final shows = await HomePodcastService.instance.recommendedShows(
      refresh: refresh,
    );
    if (!mounted) return;
    setState(() {
      _recommendations = shows;
      _loading = false;
    });
  }

  Future<void> _searchShows() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _results = const [];
      _selectedShow = null;
      _episodes = const [];
    });
    final shows = await HomePodcastService.instance.searchShows(query);
    if (!mounted) return;
    setState(() {
      _results = shows;
      _searching = false;
    });
  }

  Future<void> _openShow(HomePodcastShow show) async {
    setState(() {
      _selectedShow = show;
      _loadingEpisodes = true;
      _episodes = const [];
    });
    final episodes = await HomePodcastService.instance.latestEpisodes(show);
    if (!mounted || _selectedShow?.id != show.id) return;
    setState(() {
      _episodes = episodes;
      _loadingEpisodes = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shows = _search.text.trim().isEmpty ? _recommendations : _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Podcasts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: -.65,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar podcasts',
              visualDensity: VisualDensity.compact,
              onPressed: _loading
                  ? null
                  : () => _loadRecommendations(refresh: true),
              icon: const Icon(Icons.refresh_rounded, color: _muted, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchShows(),
          onChanged: (value) {
            if (value.trim().isEmpty && _results.isNotEmpty) {
              setState(() {
                _results = const [];
                _selectedShow = null;
                _episodes = const [];
              });
            }
          },
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar podcasts',
            hintStyle: const TextStyle(color: _muted, fontSize: 12),
            prefixIcon: const Icon(
              Icons.podcasts_rounded,
              color: _muted,
              size: 19,
            ),
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              onPressed: _searching ? null : _searchShows,
              icon: _searching
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded, color: Colors.white),
            ),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .07),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading || _searching || _loadingEpisodes)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else if (shows.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 174,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shows.length,
              separatorBuilder: (context, index) => const SizedBox(width: 13),
              itemBuilder: (context, index) => _showCard(shows[index]),
            ),
          ),
        if (_selectedShow != null && _episodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...List.generate(_episodes.length, (index) => _episodeRow(index)),
        ],
      ],
    );
  }

  Widget _showCard(HomePodcastShow show) => SizedBox(
    width: 132,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openShow(show),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: 132,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: show.artworkUrl.isEmpty
                      ? const ColoredBox(
                          color: _surface,
                          child: Icon(Icons.podcasts_rounded, color: _muted),
                        )
                      : Image.network(
                          show.artworkUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                                color: _surface,
                                child: Icon(
                                  Icons.podcasts_rounded,
                                  color: _muted,
                                ),
                              ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              show.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _episodeRow(int index) {
    final episode = _episodes[index];
    final duration = episode.durationSeconds > 0
        ? '${episode.durationSeconds ~/ 60}:${(episode.durationSeconds % 60).toString().padLeft(2, '0')}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.white.withValues(alpha: .025),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onPlay(
            HomePodcastPlayRequest(episodes: _episodes, index: index),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.play_arrow_rounded, color: _muted, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (duration.isNotEmpty)
                  Text(
                    duration,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
