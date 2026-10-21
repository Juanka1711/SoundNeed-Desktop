import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _bg = Color(0xFF0B0B12);
const _panel = Color(0xFF151522);
const _raised = Color(0xFF1D1D2B);
const _cyan = Color(0xFF83E8FF);
const _muted = Color(0xFF9292A5);
const _youtubeAndroidUserAgent =
    'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36';
const _audioExtensions = <String>[
  'mp3',
  'flac',
  'm4a',
  'mp4',
  'wav',
  'ogg',
  'opus',
  'aac',
  'wma',
  'aiff',
  'aif',
  'ape',
];

class Track {
  const Track({
    required this.path,
    required this.title,
    required this.artist,
    this.album = '',
    this.coverPath,
    this.durationMs,
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final String? coverPath;
  final int? durationMs;

  Map<String, Object?> toJson() => {
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'coverPath': coverPath,
    'durationMs': durationMs,
  };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    path: json['path'] as String,
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String? ?? '',
    album: json['album'] as String? ?? '',
    coverPath: json['coverPath'] as String?,
    durationMs: json['durationMs'] as int?,
  );
}

class _ScannedTrack {
  const _ScannedTrack(this.track, this.coverBytes);
  final Track track;
  final Uint8List? coverBytes;
}

class _OnlineTrack {
  const _OnlineTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.durationSeconds,
  });

  final String videoId;
  final String title;
  final String artist;
  final String thumbnail;
  final int durationSeconds;
}

class _ResolvedOnlineAudio {
  _ResolvedOnlineAudio({
    required this.url,
    required this.contentType,
    required this.bitrate,
  }) : resolvedAt = DateTime.now();

  final String url;
  final String contentType;
  final int bitrate;
  final DateTime resolvedAt;
}

/// Matches the HTTP defaults used by the Android NewPipeDownloader so
/// YouTube sees a modern mobile client when Dart resolves and fetches streams.
class _SoundNeedYoutubeHttpClient extends YoutubeHttpClient {
  @override
  Map<String, String> get headers => {
    ...YoutubeHttpClient.defaultHeaders,
    'user-agent': _youtubeAndroidUserAgent,
    'accept': '*/*',
    'accept-encoding': 'identity',
  };
}

List<_ScannedTrack> _scanFiles(List<String> paths) {
  final tracks = <_ScannedTrack>[];
  for (final path in paths) {
    try {
      final file = File(path);
      if (!file.existsSync()) continue;
      final metadata = readMetadata(file, getImage: true);
      final fallback = path
          .split(Platform.pathSeparator)
          .last
          .replaceAll(RegExp(r'\.[^.]+$'), '');
      final title = metadata.title?.trim();
      final artist = metadata.artist?.trim();
      final cover = metadata.pictures.isEmpty
          ? null
          : metadata.pictures.first.bytes;
      tracks.add(
        _ScannedTrack(
          Track(
            path: path,
            title: title == null || title.isEmpty ? fallback : title,
            artist: artist == null || artist.isEmpty
                ? 'Artista desconocido'
                : artist,
            album: metadata.album?.trim() ?? '',
            durationMs: metadata.duration?.inMilliseconds,
          ),
          cover,
        ),
      );
    } catch (_) {
      final fallback = path
          .split(Platform.pathSeparator)
          .last
          .replaceAll(RegExp(r'\.[^.]+$'), '');
      tracks.add(
        _ScannedTrack(
          Track(path: path, title: fallback, artist: 'Artista desconocido'),
          null,
        ),
      );
    }
  }
  return tracks;
}

void main() => runApp(const SoundNeedApp());

class SoundNeedApp extends StatelessWidget {
  const SoundNeedApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SoundNeed',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _cyan,
        surface: _panel,
        onSurface: Colors.white,
        secondary: _cyan,
      ),
      fontFamily: 'Segoe UI',
      sliderTheme: SliderThemeData(
        activeTrackColor: _cyan,
        inactiveTrackColor: Colors.white.withValues(alpha: .12),
        thumbColor: _cyan,
        overlayColor: _cyan.withValues(alpha: .12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
    ),
    home: const LibraryScreen(),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _youtube = YoutubeExplode(
    httpClient: _SoundNeedYoutubeHttpClient(),
  );
  final TextEditingController _search = TextEditingController();
  final List<Track> _tracks = [];
  final Set<String> _favorites = {};
  final Map<String, List<String>> _playlists = {};
  final List<String> _folders = [];
  final List<String> _queue = [];
  List<_OnlineTrack> _onlinePlaybackQueue = const [];
  final Map<String, _ResolvedOnlineAudio> _prefetchedOnlineAudio = {};
  final Map<String, Future<_ResolvedOnlineAudio?>> _onlineExtractionJobs = {};
  int _onlineQueueIndex = -1;
  bool _onlineAdvancing = false;
  String _section = 'Inicio';
  String? _playlistView;
  int? _currentIndex;
  bool _loading = true;
  bool _scanning = false;
  bool _queueOpen = false;
  bool _onlineMode = false;
  bool _onlineSearching = false;
  bool _onlinePlaybackLoading = false;
  String? _error;
  String? _onlineError;
  _OnlineTrack? _playingOnlineTrack;
  String _query = '';
  List<_OnlineTrack> _onlineResults = const [];
  Duration _position = Duration.zero;
  Duration? _duration;
  double _volume = .78;
  StreamSubscription<int?>? _indexSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;
  Timer? _pruneTimer;
  Timer? _onlineDebounce;
  int _onlineRequestId = 0;
  int _onlinePlaybackRequestId = 0;

  @override
  void initState() {
    super.initState();
    _restore();
    _indexSubscription = _player.currentIndexStream.listen((index) {
      if (!mounted) return;
      setState(() {
        _currentIndex = index;
        _position = Duration.zero;
        _duration = _player.duration;
      });
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _errorSubscription = _player.errorStream.listen((error) {
      final online = _playingOnlineTrack != null;
      unawaited(
        _writePlaybackLog('Player error code=${error.code}: ${error.message}'),
      );
      if (mounted) {
        setState(() {
          _error =
              '${online ? 'Audio online' : 'Reproducción'} (${error.code}): ${error.message}';
          if (online) _onlinePlaybackLoading = false;
        });
      }
    });
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          _playingOnlineTrack != null) {
        unawaited(_skipOnlineTrack(1));
      }
    });
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawTracks = prefs.getString('library.v1');
      if (rawTracks != null) {
        final decoded = jsonDecode(rawTracks) as List<dynamic>;
        _tracks.addAll(
          decoded.map((item) => Track.fromJson(item as Map<String, dynamic>)),
        );
      }
      _favorites.addAll(prefs.getStringList('favorites.v1') ?? []);
      _folders.addAll(prefs.getStringList('folders.v1') ?? []);
      final rawPlaylists = prefs.getString('playlists.v1');
      if (rawPlaylists != null) {
        final decoded = jsonDecode(rawPlaylists) as Map<String, dynamic>;
        decoded.forEach(
          (name, paths) => _playlists[name] = List<String>.from(paths as List),
        );
      }
      final lastPath = prefs.getString('lastTrack.v1');
      if (lastPath != null) {
        final index = _tracks.indexWhere((track) => track.path == lastPath);
        if (index >= 0 && File(lastPath).existsSync())
          await _loadQueue(_tracks, startAt: index, autoplay: false);
      }
      await _pruneMissingTracks();
    } catch (error) {
      _error = 'No se pudo recuperar la biblioteca: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'library.v1',
      jsonEncode(_tracks.map((track) => track.toJson()).toList()),
    );
  }

  Future<void> _pruneMissingTracks() async {
    final gone = _tracks
        .where((track) => !File(track.path).existsSync())
        .map((track) => track.path)
        .toSet();
    if (gone.isEmpty) return;
    _tracks.removeWhere((track) => gone.contains(track.path));
    _favorites.removeAll(gone);
    _playlists.updateAll(
      (_, paths) => paths.where((path) => !gone.contains(path)).toList(),
    );
    _folders.removeWhere((path) => !Directory(path).existsSync());
    await _saveLibrary();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites.v1', _favorites.toList());
    await prefs.setStringList('folders.v1', _folders);
    await _savePlaylists();
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playlists.v1', jsonEncode(_playlists));
  }

  Future<void> _importFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Audio', extensions: _audioExtensions),
      ],
    );
    if (files.isNotEmpty)
      await _indexPaths(files.map((file) => file.path).toList());
  }

  Future<void> _importFolder() async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Importar esta carpeta',
    );
    if (path == null) return;
    if (!_folders.contains(path)) {
      _folders.add(path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('folders.v1', _folders);
    }
    if (!mounted) return;
    setState(() => _scanning = true);
    try {
      final paths = <String>[];
      await for (final entity in Directory(
        path,
      ).list(recursive: true, followLinks: false)) {
        if (entity is File &&
            _audioExtensions.any(
              (ext) => entity.path.toLowerCase().endsWith('.$ext'),
            )) {
          paths.add(entity.path);
        }
      }
      await _indexPaths(paths, alreadyScanning: true);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'No se pudo leer la carpeta: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _indexPaths(
    List<String> paths, {
    bool alreadyScanning = false,
  }) async {
    final known = _tracks.map((track) => track.path.toLowerCase()).toSet();
    final unique = paths
        .where((path) => !known.contains(path.toLowerCase()))
        .toSet()
        .toList();
    if (unique.isEmpty) {
      if (mounted) _toast('Esos archivos ya están en tu biblioteca.');
      return;
    }
    if (mounted && !alreadyScanning) setState(() => _scanning = true);
    try {
      final scanned = await compute(
        _scanFiles,
        unique,
        debugLabel: 'scan audio metadata',
      );
      final support = await getApplicationSupportDirectory();
      final covers = Directory(
        '${support.path}${Platform.pathSeparator}covers',
      );
      await covers.create(recursive: true);
      for (final item in scanned) {
        var track = item.track;
        final bytes = item.coverBytes;
        if (bytes != null && bytes.isNotEmpty) {
          final name =
              '${sha1.convert(utf8.encode(track.path.toLowerCase()))}.img';
          final coverFile = File(
            '${covers.path}${Platform.pathSeparator}$name',
          );
          if (!await coverFile.exists())
            await coverFile.writeAsBytes(bytes, flush: true);
          track = Track(
            path: track.path,
            title: track.title,
            artist: track.artist,
            album: track.album,
            durationMs: track.durationMs,
            coverPath: coverFile.path,
          );
        }
        _tracks.add(track);
      }
      await _saveLibrary();
      if (mounted) setState(() {});
      if (_currentIndex == null && _tracks.isNotEmpty)
        await _loadQueue(_tracks, startAt: _tracks.length - scanned.length);
      if (mounted) _toast('Se añadieron ${scanned.length} canciones.');
    } catch (error) {
      if (mounted)
        setState(
          () => _error = 'No se pudieron importar algunos archivos: $error',
        );
    } finally {
      if (mounted && !alreadyScanning) setState(() => _scanning = false);
    }
  }

  List<Track> get _visibleTracks {
    Iterable<Track> view = _tracks;
    if (_section == 'Favoritos')
      view = view.where((track) => _favorites.contains(track.path));
    if (_section == 'Playlists' && _playlistView != null) {
      final paths = _playlists[_playlistView] ?? const <String>[];
      view = view.where((track) => paths.contains(track.path));
    }
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty)
      view = view.where(
        (track) =>
            track.title.toLowerCase().contains(query) ||
            track.artist.toLowerCase().contains(query) ||
            track.album.toLowerCase().contains(query),
      );
    return view.toList();
  }

  Future<void> _loadQueue(
    List<Track> tracks, {
    int startAt = 0,
    bool autoplay = true,
  }) async {
    if (tracks.isEmpty) return;
    _onlinePlaybackRequestId++;
    _playingOnlineTrack = null;
    _onlinePlaybackLoading = false;
    _onlinePlaybackQueue = const [];
    _onlineQueueIndex = -1;
    _error = null;
    final sources = tracks
        .map((track) => AudioSource.file(track.path))
        .toList();
    try {
      await _player.setAudioSources(
        sources,
        initialIndex: startAt.clamp(0, tracks.length - 1),
        initialPosition: Duration.zero,
      );
      _queue
        ..clear()
        ..addAll(tracks.map((track) => track.path));
      _currentIndex = startAt;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastTrack.v1', tracks[startAt].path);
      if (autoplay) await _player.play();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted)
        setState(
          () => _error =
              'No se pudo abrir este archivo. Comprueba el formato y que siga disponible. ($error)',
        );
    }
  }

  Future<void> _playTrack(Track track) async {
    final source = _visibleTracks;
    final index = source.indexWhere((item) => item.path == track.path);
    await _loadQueue(
      source.isEmpty ? [track] : source,
      startAt: index < 0 ? 0 : index,
    );
  }

  Future<void> _toggleFavorite(Track track) async {
    if (!_favorites.add(track.path)) _favorites.remove(track.path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites.v1', _favorites.toList());
    if (mounted) setState(() {});
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Nueva playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Nombre de la playlist'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    if (_playlists.containsKey(name)) {
      _toast('Ya existe una playlist con ese nombre.');
      return;
    }
    _playlists[name] = [];
    await _savePlaylists();
    setState(() {
      _section = 'Playlists';
      _playlistView = name;
    });
  }

  Future<void> _addToPlaylist(Track track) async {
    if (_playlists.isEmpty) {
      _toast('Crea primero una playlist.');
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: _panel,
        title: const Text('Añadir a playlist'),
        children: _playlists.keys
            .map(
              (name) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, name),
                child: Text(name),
              ),
            )
            .toList(),
      ),
    );
    if (name == null) return;
    final paths = _playlists[name]!;
    if (!paths.contains(track.path)) paths.add(track.path);
    await _savePlaylists();
    if (mounted) _toast('Añadida a $name.');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _writePlaybackLog(String message) async {
    try {
      final support = await getApplicationSupportDirectory();
      final logDirectory = Directory(
        '${support.path}${Platform.pathSeparator}logs',
      );
      await logDirectory.create(recursive: true);
      final file = File(
        '${logDirectory.path}${Platform.pathSeparator}soundneed.log',
      );
      final line =
          '${DateTime.now().toIso8601String()} $message${Platform.lineTerminator}';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must not interrupt playback.
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    if (_section != 'Buscar' || !_onlineMode) return;
    _onlineDebounce?.cancel();
    final requestId = ++_onlineRequestId;
    if (value.trim().isEmpty) {
      setState(() {
        _onlineResults = const [];
        _onlineSearching = false;
        _onlineError = null;
      });
      return;
    }
    setState(() {
      _onlineResults = const [];
      _onlineSearching = true;
      _onlineError = null;
    });
    _onlineDebounce = Timer(
      const Duration(milliseconds: 650),
      () => _searchOnline(value, requestId),
    );
  }

  Future<void> _searchOnline(String query, int requestId) async {
    try {
      final videos = await _youtube.search.search(query.trim());
      final results = videos
          .take(30)
          .map(
            (video) => _OnlineTrack(
              videoId: video.id.value,
              title: video.title,
              artist: video.author,
              thumbnail: video.thumbnails.highResUrl,
              durationSeconds: video.duration?.inSeconds ?? 0,
            ),
          )
          .where((track) => track.videoId.isNotEmpty && track.title.isNotEmpty)
          .toList();
      if (!mounted || requestId != _onlineRequestId) return;
      setState(() {
        _onlineResults = results;
        _onlineSearching = false;
        _onlineError = results.isEmpty
            ? 'No encontramos resultados. Prueba con otra búsqueda.'
            : null;
      });
    } catch (_) {
      if (!mounted || requestId != _onlineRequestId) return;
      setState(() {
        _onlineResults = const [];
        _onlineSearching = false;
        _onlineError = 'No se pudo buscar en YouTube. Comprueba tu conexión e inténtalo de nuevo.';
      });
    }
  }

  void _setOnlineMode(bool online) {
    setState(() {
      _onlineMode = online;
      _onlineResults = const [];
      _onlineError = null;
      _onlineSearching = false;
    });
    _onlineDebounce?.cancel();
    final requestId = ++_onlineRequestId;
    if (online && _query.trim().isNotEmpty) {
      setState(() => _onlineSearching = true);
      _onlineDebounce = Timer(
        const Duration(milliseconds: 150),
        () => _searchOnline(_query, requestId),
      );
    }
  }

  Future<void> _openOnlineTrack(_OnlineTrack track) async {
    final uri = Uri.https('www.youtube.com', '/watch', {'v': track.videoId});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _toast('No se pudo abrir el navegador.');
  }

  Future<void> _playOnlineTrack(
    _OnlineTrack track, {
    List<_OnlineTrack>? queue,
    int? queueIndex,
  }) async {
    final requestId = ++_onlinePlaybackRequestId;
    _onlineDebounce?.cancel();
    _queue.clear();
    _currentIndex = null;
    if (queue != null) _onlinePlaybackQueue = List.of(queue);
    if (_onlinePlaybackQueue.isEmpty) _onlinePlaybackQueue = [track];
    _onlineQueueIndex =
        queueIndex ??
        _onlinePlaybackQueue.indexWhere(
          (item) => item.videoId == track.videoId,
        );
    setState(() {
      _playingOnlineTrack = track;
      _onlinePlaybackLoading = true;
      _error = null;
      _position = Duration.zero;
      _duration = null;
    });
    try {
      await _writePlaybackLog('Resolving online audio stream');
      await _player.stop();
      File? audioFile = await _getCachedOnlineAudio(track);
      AudioSource? directSource;
      if (requestId != _onlinePlaybackRequestId) return;
      Object? nativeExtractorError;

      if (audioFile == null) {
        try {
          final cachedExtraction = _prefetchedOnlineAudio.remove(track.videoId);
          final extracted =
              cachedExtraction != null &&
                  DateTime.now().difference(cachedExtraction.resolvedAt) <
                      const Duration(hours: 2)
              ? cachedExtraction
              : await _resolveNativeOnlineAudio(track.videoId);
          if (requestId != _onlinePlaybackRequestId) return;
          if (extracted != null) {
            await _writePlaybackLog(
              'NewPipe resolved audio: type=${extracted.contentType}, bitrate=${extracted.bitrate}; streaming directly',
            );
            // The Windows WinRT player rejects native request headers. The
            // NewPipe URL is signed and can be streamed directly without
            // attaching headers to the platform source.
            directSource = AudioSource.uri(Uri.parse(extracted.url));
          }
        } catch (error) {
          nativeExtractorError = error;
          await _writePlaybackLog('Native NewPipe extraction failed: $error');
        }
      }

      if (audioFile == null && directSource == null) {
        try {
          final manifest = await _resolveOnlineManifest(track.videoId);
          if (requestId != _onlinePlaybackRequestId) return;
          final mp4Audio = manifest.audioOnly.where(
            (stream) => stream.container == StreamContainer.mp4,
          );
          final audio = (mp4Audio.isEmpty ? manifest.audioOnly : mp4Audio)
              .withHighestBitrate();
          await _writePlaybackLog(
            'Dart extractor resolved: container=${audio.container.name}, codec=${audio.codec.mimeType}, audioOnly=${manifest.audioOnly.length}',
          );
          audioFile = await _cacheOnlineAudio(track, audio, requestId);
        } catch (fallbackError) {
          if (nativeExtractorError != null) {
            throw StateError(
              'NewPipe: $nativeExtractorError; Dart: $fallbackError',
            );
          }
          rethrow;
        }
      }

      if (audioFile == null) {
        if (directSource == null) {
          throw StateError(
            'No se pudo extraer un stream de audio para este video.',
          );
        }
      }
      if (requestId != _onlinePlaybackRequestId) return;
      if (audioFile != null) {
        await _writePlaybackLog(
          'Using cached online audio: bytes=${await audioFile.length()}',
        );
      }
      await _player.setAudioSource(
        directSource ?? AudioSource.file(audioFile!.path),
      );
      if (requestId != _onlinePlaybackRequestId) return;
      unawaited(_startOnlinePlayback(requestId));
      _currentIndex = null;
      if (mounted) setState(() => _onlinePlaybackLoading = false);
      await _writePlaybackLog('Audio source loaded; playback requested');
    } catch (error) {
      if (!mounted || requestId != _onlinePlaybackRequestId) return;
      await _writePlaybackLog('Online playback setup failed: $error');
      final detail = error.toString().toLowerCase();
      final message =
          detail.contains('not a bot') || detail.contains('sign in to confirm')
          ? 'YouTube bloqueó esta solicitud automática. Prueba otro resultado o inténtalo más tarde.'
          : error is VideoUnplayableException
          ? 'YouTube no entregó un stream de audio reproducible a SoundNeed. Esto no confirma que el video sea privado o haya sido retirado; prueba otro resultado o inténtalo más tarde.'
          : 'No se pudo obtener o reproducir el audio online. Intenta con otro resultado. ($error)';
      setState(() {
        _onlinePlaybackLoading = false;
        _error = message;
      });
    }
  }

  Future<void> _skipOnlineTrack(int direction) async {
    if (_onlineAdvancing || _playingOnlineTrack == null) return;
    final nextIndex = _onlineQueueIndex + direction;
    if (nextIndex < 0 || nextIndex >= _onlinePlaybackQueue.length) return;
    _onlineAdvancing = true;
    try {
      await _playOnlineTrack(
        _onlinePlaybackQueue[nextIndex],
        queue: _onlinePlaybackQueue,
        queueIndex: nextIndex,
      );
    } finally {
      _onlineAdvancing = false;
    }
  }

  Future<_ResolvedOnlineAudio?> _resolveNativeOnlineAudio(
    String videoId,
  ) async {
    final current = _prefetchedOnlineAudio[videoId];
    if (current != null &&
        DateTime.now().difference(current.resolvedAt) <
            const Duration(hours: 2)) {
      return current;
    }
    final pending = _onlineExtractionJobs[videoId];
    if (pending != null) return pending;

    final future = _extractWithNativeNewPipe(videoId);
    _onlineExtractionJobs[videoId] = future;
    try {
      return await future;
    } finally {
      if (identical(_onlineExtractionJobs[videoId], future)) {
        _onlineExtractionJobs.remove(videoId);
      }
    }
  }

  Future<void> _prefetchNextOnlineTrack(int requestId) async {
    final nextIndex = _onlineQueueIndex + 1;
    if (requestId != _onlinePlaybackRequestId ||
        nextIndex < 0 ||
        nextIndex >= _onlinePlaybackQueue.length) {
      return;
    }
    final currentId = _playingOnlineTrack?.videoId;
    final next = _onlinePlaybackQueue[nextIndex];
    if (next.videoId == currentId) return;

    final prepared = _prefetchedOnlineAudio[next.videoId];
    if (prepared != null &&
        DateTime.now().difference(prepared.resolvedAt) <
            const Duration(hours: 2)) {
      return;
    }
    try {
      final cache = await _onlineAudioCacheFile(next);
      if (await cache.exists() && await cache.length() > 0) return;
      if (requestId != _onlinePlaybackRequestId) return;
      final audio = await _resolveNativeOnlineAudio(next.videoId);
      if (audio != null &&
          requestId == _onlinePlaybackRequestId &&
          _playingOnlineTrack?.videoId == currentId) {
        _prefetchedOnlineAudio[next.videoId] = audio;
        await _writePlaybackLog(
          'Prepared next online track in memory: video=${next.videoId}',
        );
      }
    } catch (error) {
      await _writePlaybackLog('Next online track prefetch failed: $error');
    }
  }

  Future<StreamManifest> _resolveOnlineManifest(String videoId) async {
    final clients = <(String, YoutubeApiClient, bool)>[
      ('Android página', YoutubeApiClient.androidSdkless, true),
      ('Android API', YoutubeApiClient.androidSdkless, false),
      ('TV', YoutubeApiClient.tv, false),
      ('iOS', YoutubeApiClient.ios, false),
      ('Android VR', YoutubeApiClient.androidVr, false),
      ('Safari', YoutubeApiClient.safari, false),
    ];
    Object? lastError;
    for (final (name, client, requireWatchPage) in clients) {
      try {
        await _writePlaybackLog('Trying YouTube extraction client: $name');
        final manifest = await _youtube.videos.streamsClient
            .getManifest(
              videoId,
              ytClients: [client],
              requireWatchPage: requireWatchPage,
            )
            .timeout(const Duration(seconds: 20));
        if (manifest.audioOnly.isNotEmpty) {
          await _writePlaybackLog(
            'YouTube extraction client $name returned ${manifest.audioOnly.length} audio streams',
          );
          return manifest;
        }
        lastError = StateError('El cliente $name no ofreció audio disponible.');
      } catch (error) {
        lastError = error;
        await _writePlaybackLog('YouTube client $name failed: $error');
      }
    }
    if (lastError is Error && lastError.stackTrace != null) {
      Error.throwWithStackTrace(lastError, lastError.stackTrace!);
    }
    throw lastError ?? StateError('YouTube no ofreció audio para este video.');
  }

  Future<_ResolvedOnlineAudio?> _extractWithNativeNewPipe(
    String videoId,
  ) async {
    final appDirectory = File(Platform.resolvedExecutable).parent;
    final jar = File(
      '${appDirectory.path}${Platform.pathSeparator}soundneed-newpipe-extractor-all.jar',
    );
    if (!await jar.exists()) {
      await _writePlaybackLog('Native NewPipe helper is not bundled');
      throw StateError(
        'El extractor NewPipe no está junto al ejecutable. Comprueba que la compilación de Windows haya generado y copiado soundneed-newpipe-extractor-all.jar.',
      );
    }

    final java = await _findJavaExecutable();
    if (java == null) {
      await _writePlaybackLog('No Java runtime found for NewPipe helper');
      throw StateError(
        'No se encontró Java para iniciar el extractor NewPipe.',
      );
    }

    final process = await Process.start(java, [
      '-jar',
      jar.path,
      videoId,
    ], runInShell: false);
    final stdoutFuture = utf8.decoder.bind(process.stdout).join();
    final stderrFuture = utf8.decoder.bind(process.stderr).join();
    final exitCode = await process.exitCode.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        process.kill();
        throw TimeoutException('NewPipe tardó más de 45 segundos.');
      },
    );
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    if (exitCode != 0) {
      throw ProcessException(
        java,
        ['-jar', jar.path, videoId],
        stderr.trim().isEmpty
            ? 'NewPipe no pudo extraer el audio.'
            : stderr.trim(),
        exitCode,
      );
    }

    final lines = stdout.trim().split(RegExp(r'\r?\n'));
    if (lines.length < 3) {
      throw FormatException(
        'NewPipe devolvió una respuesta incompleta: $stderr',
      );
    }
    final url = lines[lines.length - 3].trim();
    final contentType = lines[lines.length - 2].trim();
    final bitrate = int.tryParse(lines.last.trim()) ?? 0;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw FormatException('NewPipe no devolvió una URL de audio válida.');
    }
    return _ResolvedOnlineAudio(
      url: url,
      contentType: contentType,
      bitrate: bitrate,
    );
  }

  Future<String?> _findJavaExecutable() async {
    final candidates = <String>[
      if (Platform.environment['JAVA_HOME'] case final javaHome?)
        '$javaHome${Platform.pathSeparator}bin${Platform.pathSeparator}java.exe',
      if (Platform.environment['ProgramFiles'] case final programFiles?)
        '$programFiles${Platform.pathSeparator}Android${Platform.pathSeparator}Android Studio${Platform.pathSeparator}jbr${Platform.pathSeparator}bin${Platform.pathSeparator}java.exe',
      if (Platform.environment['LOCALAPPDATA'] case final localAppData?)
        '$localAppData${Platform.pathSeparator}Programs${Platform.pathSeparator}Android Studio${Platform.pathSeparator}jbr${Platform.pathSeparator}bin${Platform.pathSeparator}java.exe',
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    try {
      final result = await Process.run('java.exe', ['-version']);
      if (result.exitCode == 0) return 'java.exe';
    } catch (_) {
      // The app can still use the Dart extractor fallback without Java.
    }
    return null;
  }

  Future<File?> _cacheOnlineAudio(
    _OnlineTrack track,
    AudioOnlyStreamInfo audio,
    int requestId,
  ) async {
    final file = await _onlineAudioCacheFile(track);
    if (await file.exists() && await file.length() > 0) return file;
    await _writePlaybackLog(
      'Downloading YouTube audio to disk cache: video=${track.videoId}',
    );
    return _writeOnlineAudioCache(
      track,
      file,
      _youtube.videos.streamsClient
          .get(audio)
          .timeout(const Duration(minutes: 5)),
      requestId,
    );
  }

  Future<File?> _writeOnlineAudioCache(
    _OnlineTrack track,
    File file,
    Stream<List<int>> bytes,
    int requestId,
  ) async {
    final sink = file.openWrite();
    var bytesWritten = 0;
    try {
      await for (final chunk in bytes) {
        if (requestId != _onlinePlaybackRequestId) {
          await sink.close();
          if (await file.exists()) await file.delete();
          return null;
        }
        sink.add(chunk);
        bytesWritten += chunk.length;
      }
      await sink.flush();
      await sink.close();
      if (bytesWritten == 0) {
        throw StateError('YouTube entregó un flujo de audio vacío.');
      }
      return file;
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<File> _onlineAudioCacheFile(_OnlineTrack track) async {
    final support = await getApplicationSupportDirectory();
    final cache = Directory(
      '${support.path}${Platform.pathSeparator}online-audio-cache',
    );
    await cache.create(recursive: true);
    final key = sha1.convert(utf8.encode(track.videoId)).toString();
    return File('${cache.path}${Platform.pathSeparator}$key.mp4');
  }

  Future<File?> _getCachedOnlineAudio(_OnlineTrack track) async {
    final file = await _onlineAudioCacheFile(track);
    if (await file.exists() && await file.length() > 0) {
      await _writePlaybackLog(
        'Using cached online audio: video=${track.videoId}',
      );
      return file;
    }
    return null;
  }

  Future<void> _startOnlinePlayback(int requestId) async {
    try {
      unawaited(_prefetchNextOnlineTrack(requestId));
      await _player.play();
    } catch (error) {
      if (requestId != _onlinePlaybackRequestId) return;
      await _writePlaybackLog('Online playback failed: $error');
      if (mounted) {
        setState(() {
          _onlinePlaybackLoading = false;
          _error = 'Falló la reproducción de audio online: $error';
        });
      }
    }
  }

  String _time(Duration? duration) {
    if (duration == null || duration.isNegative) return '--:--';
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _indexSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _errorSubscription?.cancel();
    _pruneTimer?.cancel();
    _onlineDebounce?.cancel();
    _onlineRequestId++;
    _onlinePlaybackRequestId++;
    _search.dispose();
    _youtube.close();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current =
        _currentIndex != null &&
            _currentIndex! >= 0 &&
            _currentIndex! < _queue.length
        ? _tracks
              .where((track) => track.path == _queue[_currentIndex!])
              .firstOrNull
        : null;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;
          return Row(
            children: [
              _sidebar(compact),
              Expanded(
                child: Column(
                  children: [
                    _topBar(compact),
                    Expanded(child: _mainContent(compact)),
                    _playerBar(
                      current,
                      compact,
                      onlineTrack: _playingOnlineTrack,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sidebar(bool compact) => Container(
    width: compact ? 76 : 236,
    color: _panel,
    padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: compact ? 5 : 10, bottom: 34),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _cyan,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: _bg,
                  size: 22,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 11),
                const Text(
                  'SoundNeed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                  ),
                ),
              ],
            ],
          ),
        ),
        _navItem(Icons.home_rounded, 'Inicio', compact),
        _navItem(Icons.search_rounded, 'Buscar', compact),
        _navItem(Icons.library_music_rounded, 'Tu música', compact),
        _navItem(Icons.favorite_rounded, 'Favoritos', compact),
        const SizedBox(height: 25),
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              'COLECCIÓN',
              style: TextStyle(
                color: _muted.withValues(alpha: .8),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        _navItem(Icons.album_rounded, 'Álbumes', compact),
        _navItem(Icons.people_alt_rounded, 'Artistas', compact),
        _navItem(Icons.queue_music_rounded, 'Playlists', compact),
        if (_section == 'Playlists' && !compact)
          ..._playlists.keys.map(
            (name) => Padding(
              padding: const EdgeInsets.only(left: 38),
              child: _navItem(Icons.circle, name, compact, small: true),
            ),
          ),
        const Spacer(),
        _navItem(Icons.settings_outlined, 'Ajustes', compact),
        if (!compact)
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 10),
            child: Text(
              'MÚSICA, A TU MANERA',
              style: TextStyle(
                color: Color(0xFF5D5D70),
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _navItem(
    IconData icon,
    String label,
    bool compact, {
    bool small = false,
  }) {
    final selected =
        _section == label ||
        (_section == 'Playlists' && label == _playlistView);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: compact ? label : '',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              if (_playlists.containsKey(label)) {
                _section = 'Playlists';
                _playlistView = label;
              } else {
                _section = label;
                _playlistView = null;
              }
              if (label == 'Buscar')
                FocusScope.of(context).requestFocus(FocusNode());
            });
          },
          child: Container(
            height: small ? 34 : 42,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
            decoration: BoxDecoration(
              color: selected
                  ? _cyan.withValues(alpha: .11)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: small ? 13 : 19,
                  color: selected ? _cyan : _muted,
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: small ? 12 : 13,
                        color: selected ? Colors.white : _muted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
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

  Widget _topBar(bool compact) => Container(
    height: 76,
    padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 34),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: .04)),
      ),
    ),
    child: Row(
      children: [
        if (_section == 'Buscar')
          Expanded(child: _searchField())
        else
          const Spacer(),
        if (_section != 'Buscar')
          SizedBox(width: compact ? 150 : 290, child: _searchField()),
        const SizedBox(width: 14),
        if (!compact)
          Text(
            _scanning
                ? 'Analizando archivos…'
                : _section == 'Buscar' && _onlineMode
                ? 'Búsqueda online · YouTube'
                : 'Biblioteca local',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Importar canciones',
          onPressed: _scanning ? null : _importFiles,
          icon: const Icon(Icons.audio_file_outlined, color: _cyan),
        ),
        IconButton(
          tooltip: 'Importar carpeta',
          onPressed: _scanning ? null : _importFolder,
          icon: const Icon(Icons.create_new_folder_outlined, color: _cyan),
        ),
      ],
    ),
  );

  Widget _searchField() => TextField(
    controller: _search,
    onChanged: _onSearchChanged,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: 'Buscar canciones o artistas',
      hintStyle: const TextStyle(color: _muted, fontSize: 12),
      prefixIcon: const Icon(Icons.search, size: 18, color: _muted),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () {
                _search.clear();
                _onSearchChanged('');
              },
            ),
      filled: true,
      fillColor: _raised,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _mainContent(bool compact) {
    final tracks = _visibleTracks;
    final title = _section == 'Playlists' && _playlistView != null
        ? _playlistView!
        : _section;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 22 : 38,
            30,
            compact ? 22 : 38,
            28,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _section == 'Inicio'
                            ? 'TU ESPACIO MUSICAL'
                            : 'SOUNDNEED  /  ${_section.toUpperCase()}',
                        style: const TextStyle(
                          color: _cyan,
                          fontSize: 10,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: compact ? 29 : 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _section == 'Buscar' && _onlineMode
                            ? 'Resultados de YouTube · reproduce audio en SoundNeed'
                            : '${tracks.length} canciones en tu biblioteca',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_section == 'Playlists')
                  IconButton(
                    tooltip: 'Crear playlist',
                    onPressed: _createPlaylist,
                    icon: const Icon(Icons.add_circle_outline, color: _cyan),
                  ),
              ],
            ),
            if (_section == 'Buscar') ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.library_music_outlined, size: 16),
                      label: Text('Tu música'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.public, size: 16),
                      label: Text('Buscar online'),
                    ),
                  ],
                  selected: {_onlineMode},
                  onSelectionChanged: (selection) =>
                      _setOnlineMode(selection.first),
                ),
              ),
            ],
            const SizedBox(height: 28),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(64),
                  child: CircularProgressIndicator(color: _cyan),
                ),
              )
            else if (_section == 'Ajustes')
              _settingsPanel()
            else if (_section == 'Álbumes' || _section == 'Artistas')
              _notAvailable(
                '$title agrupados',
                'La biblioteca ya lee álbum y artista de los metadatos. La vista agrupada estará disponible en una actualización futura.',
              )
            else if (_section == 'Buscar' && _onlineMode)
              _onlineSearchPanel()
            else if (tracks.isEmpty)
              _emptyState()
            else
              _trackTable(tracks, compact),
            const SizedBox(height: 95),
          ],
        ),
        if (_error != null)
          Positioned(
            left: 20,
            right: 20,
            bottom: 14,
            child: Material(
              color: const Color(0xFF512C36),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline, color: Colors.white),
                title: Text(_error!, style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  onPressed: () => setState(() => _error = null),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
        if (_queueOpen)
          Positioned(
            top: 14,
            right: 16,
            bottom: 14,
            width: 310,
            child: _queuePanel(),
          ),
      ],
    );
  }

  Widget _onlineSearchPanel() {
    if (_query.trim().isEmpty) {
      return _notAvailable(
        'Busca música en YouTube',
        'Escribe el nombre de una canción o artista. Pulsa el icono de reproducción para escucharla en SoundNeed.',
      );
    }
    if (_onlineSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _cyan),
              SizedBox(height: 14),
              Text(
                'Buscando en YouTube…',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (_onlineError != null) {
      return _notAvailable(
        _onlineError!,
        'Revisa la conexión a internet o cambia la búsqueda.',
      );
    }
    if (_onlineResults.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: .045)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'RESULTADOS ONLINE',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_onlineResults.length} videos',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: .05)),
          ...List.generate(
            _onlineResults.length,
            (index) => _onlineTrackRow(_onlineResults[index], index),
          ),
        ],
      ),
    );
  }

  Widget _onlineTrackRow(_OnlineTrack track, int index) {
    final selected = _playingOnlineTrack?.videoId == track.videoId;
    final queue = _onlineResults;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          IconButton(
            tooltip: selected && _player.playing
                ? 'En reproducción'
                : 'Reproducir en SoundNeed',
            onPressed: _onlinePlaybackLoading && selected
                ? null
                : () =>
                      _playOnlineTrack(track, queue: queue, queueIndex: index),
            icon: selected && _onlinePlaybackLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _cyan,
                    ),
                  )
                : Icon(
                    selected && _player.playing
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    color: selected ? _cyan : _muted,
                  ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 42,
              child: Image.network(
                track.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _coverPlaceholder(42),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: () =>
                  _playOnlineTrack(track, queue: queue, queueIndex: index),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? _cyan : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (track.durationSeconds > 0)
            Text(
              _time(Duration(seconds: track.durationSeconds)),
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          IconButton(
            tooltip: 'Abrir en YouTube',
            onPressed: () => _openOnlineTrack(track),
            icon: const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _queuePanel() => Material(
    color: _raised,
    elevation: 14,
    borderRadius: BorderRadius.circular(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 8, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Cola de reproducción',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_queue.length}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              IconButton(
                tooltip: 'Cerrar cola',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _queueOpen = false),
                icon: const Icon(Icons.close, size: 17),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: .07)),
        Expanded(
          child: _queue.isEmpty
              ? const Center(
                  child: Text(
                    'La cola está vacía',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: _queue.length,
                  itemBuilder: (context, index) {
                    final track = _tracks
                        .where((item) => item.path == _queue[index])
                        .firstOrNull;
                    if (track == null) return const SizedBox.shrink();
                    final selected = index == _currentIndex;
                    return ListTile(
                      dense: true,
                      onTap: () => _player.seek(Duration.zero, index: index),
                      leading: _cover(track, 34),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? _cyan : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                      trailing: selected
                          ? const Icon(Icons.volume_up, size: 15, color: _cyan)
                          : null,
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Widget _emptyState() => Container(
    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 26),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .05)),
    ),
    child: Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.library_music_outlined,
            color: _cyan,
            size: 28,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _query.isNotEmpty
              ? 'No encontramos coincidencias'
              : _section == 'Favoritos'
              ? 'Aún no tienes favoritos'
              : _section == 'Playlists' && _playlistView != null
              ? 'Esta playlist está vacía'
              : 'Empieza con tu música',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _query.isNotEmpty ? 'Prueba con otro nombre de canción o artista.' : 'Importa archivos o una carpeta para crear tu biblioteca local.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        if (_query.isEmpty && _section != 'Favoritos') ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _importFiles,
                icon: const Icon(Icons.audio_file_outlined),
                label: const Text('Elegir canciones'),
              ),
              FilledButton.tonalIcon(
                onPressed: _importFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Elegir carpeta'),
              ),
              if (_section == 'Playlists')
                OutlinedButton.icon(
                  onPressed: _createPlaylist,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear playlist'),
                ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _trackTable(List<Track> tracks, bool compact) => Container(
    decoration: BoxDecoration(
      color: _panel.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: .045)),
    ),
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 20,
            14,
            compact ? 14 : 20,
            10,
          ),
          child: Row(
            children: [
              const SizedBox(width: 34),
              const Expanded(
                flex: 5,
                child: Text(
                  'TÍTULO',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!compact)
                const Expanded(
                  flex: 3,
                  child: Text(
                    'ÁLBUM',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 42),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: .05)),
        ...List.generate(
          tracks.length,
          (index) => _trackRow(tracks[index], index, compact),
        ),
      ],
    ),
  );

  Widget _trackRow(Track track, int index, bool compact) {
    final playing =
        _currentIndex != null &&
        _currentIndex! < _queue.length &&
        _queue[_currentIndex!] == track.path &&
        _player.playing;
    return InkWell(
      onDoubleTap: () => _playTrack(track),
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 14 : 20, 9, compact ? 7 : 14, 9),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Reproducir',
                onPressed: () => _playTrack(track),
                icon: Icon(
                  playing ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                  color: playing ? _cyan : _muted,
                  size: 19,
                ),
              ),
            ),
            _cover(track, 42),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: playing ? _cyan : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!compact)
              Expanded(
                flex: 3,
                child: Text(
                  track.album.isEmpty ? '—' : track.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            SizedBox(
              width: 48,
              child: Text(
                _time(
                  track.durationMs == null
                      ? null
                      : Duration(milliseconds: track.durationMs!),
                ),
                textAlign: TextAlign.right,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              iconSize: 17,
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'favorite') _toggleFavorite(track);
                if (value == 'playlist') _addToPlaylist(track);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'favorite',
                  child: Text(
                    _favorites.contains(track.path)
                        ? 'Quitar de favoritos'
                        : 'Añadir a favoritos',
                  ),
                ),
                const PopupMenuItem(
                  value: 'playlist',
                  child: Text('Añadir a playlist'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(Track track, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .2),
    child: SizedBox(
      width: size,
      height: size,
      child: track.coverPath != null && File(track.coverPath!).existsSync()
          ? Image.file(
              File(track.coverPath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _coverPlaceholder(size),
            )
          : _coverPlaceholder(size),
    ),
  );

  Widget _coverPlaceholder(double size) => Container(
    color: _raised,
    child: Icon(
      Icons.music_note_rounded,
      color: _cyan.withValues(alpha: .75),
      size: size * .48,
    ),
  );

  Widget _playerBar(Track? track, bool compact, {_OnlineTrack? onlineTrack}) {
    final hasTrack = track != null || onlineTrack != null;
    return Container(
      height: 91,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 28),
      decoration: BoxDecoration(
        color: _panel,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .07)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 170 : 245,
            child: Row(
              children: [
                if (track != null)
                  _cover(track, 48)
                else if (onlineTrack != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.network(
                        onlineTrack.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _coverPlaceholder(48),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _raised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.music_note, color: _muted),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track?.title ??
                            onlineTrack?.title ??
                            'Elige una canción',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track?.artist ??
                            onlineTrack?.artist ??
                            'Tu biblioteca te espera',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (track != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Favorito',
                    onPressed: () => _toggleFavorite(track),
                    icon: Icon(
                      _favorites.contains(track.path)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 17,
                      color: _favorites.contains(track.path) ? _cyan : _muted,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Anterior',
                      onPressed: _playingOnlineTrack != null
                          ? (_onlineQueueIndex > 0
                                ? () => _skipOnlineTrack(-1)
                                : null)
                          : (_queue.isEmpty ? null : _player.seekToPrevious),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.skip_previous_rounded, size: 22),
                    ),
                    const SizedBox(width: 7),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return InkWell(
                          onTap: !hasTrack
                              ? _importFolder
                              : () =>
                                    playing ? _player.pause() : _player.play(),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: _cyan,
                              shape: BoxShape.circle,
                            ),
                            child: _onlinePlaybackLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(9),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _bg,
                                    ),
                                  )
                                : Icon(
                                    !hasTrack
                                        ? Icons.add
                                        : playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: _bg,
                                    size: 22,
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 7),
                    IconButton(
                      tooltip: 'Siguiente',
                      onPressed: _playingOnlineTrack != null
                          ? (_onlineQueueIndex >= 0 &&
                                    _onlineQueueIndex <
                                        _onlinePlaybackQueue.length - 1
                                ? () => _skipOnlineTrack(1)
                                : null)
                          : (_queue.isEmpty ? null : _player.seekToNext),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.skip_next_rounded, size: 22),
                    ),
                  ],
                ),
                if (!compact)
                  Row(
                    children: [
                      SizedBox(
                        width: 38,
                        child: Text(
                          _time(_position),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: _muted, fontSize: 9),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value:
                              _duration == null ||
                                  _duration!.inMilliseconds <= 0
                              ? 0
                              : _position.inMilliseconds
                                    .clamp(0, _duration!.inMilliseconds)
                                    .toDouble(),
                          max:
                              _duration == null ||
                                  _duration!.inMilliseconds <= 0
                              ? 1
                              : _duration!.inMilliseconds.toDouble(),
                          onChanged: !hasTrack || _duration == null
                              ? null
                              : (value) => _player.seek(
                                  Duration(milliseconds: value.round()),
                                ),
                        ),
                      ),
                      SizedBox(
                        width: 38,
                        child: Text(
                          _time(_duration),
                          style: const TextStyle(color: _muted, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(
            width: compact ? 80 : 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: _queueOpen ? 'Ocultar cola' : 'Ver cola',
                  onPressed: () => setState(() => _queueOpen = !_queueOpen),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.queue_music,
                    size: 18,
                    color: _queueOpen ? _cyan : _muted,
                  ),
                ),
                if (!compact) ...[
                  const Icon(Icons.volume_up_outlined, size: 17, color: _muted),
                  SizedBox(
                    width: 100,
                    child: Slider(
                      value: _volume,
                      onChanged: (value) {
                        setState(() => _volume = value);
                        _player.setVolume(value);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsPanel() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Biblioteca local',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          '${_folders.length} carpetas importadas · ${_tracks.length} canciones',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _importFolder,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Añadir carpeta'),
        ),
        const SizedBox(height: 22),
        const Text(
          'En desarrollo',
          style: TextStyle(color: _cyan, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        const Text(
          'La búsqueda online consulta YouTube y reproduce el audio seleccionado dentro del reproductor. Letras sincronizadas, recomendaciones y SoundNeed Connect siguen pendientes.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 20),
        const Text(
          'Diagnóstico de reproducción online',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        const Text(
          'Se registran la resolución del stream y los errores del motor de audio en:',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        FutureBuilder<Directory>(
          future: getApplicationSupportDirectory(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final path =
                '${snapshot.data!.path}${Platform.pathSeparator}logs${Platform.pathSeparator}soundneed.log';
            return SelectableText(
              path,
              style: const TextStyle(color: _cyan, fontSize: 11),
            );
          },
        ),
      ],
    ),
  );

  Widget _notAvailable(String title, String message) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}
