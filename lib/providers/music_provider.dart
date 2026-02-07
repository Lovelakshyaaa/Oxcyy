import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

// ====================================================================
// 1. ADVANCED CLIENT CONFIGURATION (Rotating, Persistent, Spoofed)
// ====================================================================

/// A pool of client configurations mimicking various YouTube frontends.
/// Rotate through these when one fails.
final List<yt.YoutubeApiClient> _clientPool = [
  // Android VR Client (High Success Rate - The "Golden Key")
  yt.YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.65.10',
        'deviceModel': 'Quest 3',
        'userAgent':
            'Mozilla/5.0 (Linux; Android 12L; Quest 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
        'osVersion': '12L',
        'osName': 'Android',
        'androidSdkVersion': '32',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
      'contextClientName': 28,
      'requireJsPlayer': false,
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),

  // Android SDKless (Reliable Fallback)
  yt.YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'ANDROID',
        'clientVersion': '20.10.38',
        'userAgent':
            'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
        'osName': 'Android',
        'osVersion': '11',
      },
    },
    'contextClientName': 3,
    'requireJsPlayer': false,
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),

  // WEB Client (Mimicking Desktop Browser)
  yt.YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'WEB',
        'clientVersion': '2.20221220.09.00',
        'userAgent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
        'osName': 'Windows',
        'osVersion': '10.0',
      },
    },
    'contextClientName': 1,
    'requireJsPlayer': true,
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),

  // iOS Client (Good backup for standard streams)
  yt.YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'IOS',
        'clientVersion': '19.09.3',
        'userAgent':
            'com.google.ios.youtube/19.09.3 (iPhone14,5; U; CPU iOS 15_6 like Mac OS X)',
        'osName': 'iOS',
        'osVersion': '15.6',
        'deviceModel': 'iPhone14,5',
      },
    },
    'contextClientName': 5,
    'requireJsPlayer': false,
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
];

// ====================================================================
// 2. UTILITY: GET MANIFEST WITH CLIENT ROTATION & RETRY LOGIC
// ====================================================================

Future<yt.StreamManifest?> _getManifestWithRetry(String videoId,
    {int maxAttempts = 3}) async {
  yt.YoutubeExplode ytInstance = yt.YoutubeExplode();
  yt.StreamManifest? manifest;
  Exception? lastError;

  // Shuffle the pool for each attempt to avoid detection patterns
  List<yt.YoutubeApiClient> shuffledPool = List.from(_clientPool);
  shuffledPool.shuffle();

  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    for (var client in shuffledPool) {
      try {
        print(
            'Attempt $attempt: Fetching manifest for $videoId with client: ${client.context['client']?['clientName']}');
        
        // CRITICAL: We pass ONLY one client at a time to isolate failures
        manifest = await ytInstance.videos.streamsClient
            .getManifest(videoId, ytClients: [client]);
            
        if (manifest != null && manifest.audioOnly.isNotEmpty) {
          print('Success with client: ${client.context['client']?['clientName']}');
          return manifest;
        }
      } catch (e) {
        lastError = e as Exception;
        print('Client ${client.context['client']?['clientName']} failed: $e');
        // Short delay before trying next client
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    // Exponential backoff before retrying the whole pool
    await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
  }

  if (manifest == null) {
    print('All manifest fetch attempts failed. Last error: $lastError');
    throw lastError ?? Exception('Could not retrieve stream manifest.');
  }
  return manifest;
}

// ====================================================================
// 3. UTILITY: GET BEST AUDIO STREAM (WITH FALLBACKS)
// ====================================================================

yt.AudioOnlyStreamInfo? _getBestAudioStream(yt.StreamManifest manifest) {
  // Priority 1: Highest bitrate m4a (Reliable on iOS/Android)
  var m4aStreams = manifest.audioOnly.where((s) => s.container.name == 'm4a');
  if (m4aStreams.isNotEmpty) {
    return m4aStreams.withHighestBitrate();
  }

  // Priority 2: Highest bitrate webm/opus (High Quality)
  var opusStreams = manifest.audioOnly.where((s) => s.container.name == 'webm');
  if (opusStreams.isNotEmpty) {
    return opusStreams.withHighestBitrate();
  }

  // Priority 3: Any audio stream
  if (manifest.audioOnly.isNotEmpty) {
    return manifest.audioOnly.first;
  }

  return null;
}

// ====================================================================
// 4. DATA MODELS
// ====================================================================

class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbUrl;
  final String type;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    this.type = 'video',
  });
}

// ====================================================================
// 5. MAIN PROVIDER CLASS
// ====================================================================

class MusicProvider with ChangeNotifier {
  // Static
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";

  // State
  final _player = AudioPlayer();
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  List<Song> _searchResults = [];
  List<Song> _queue = [];
  int _currentIndex = -1;
  String? _nextPageToken;
  String _currentQuery = "";
  bool _isFetchingMore = false;
  bool _isLoadingSong = false;
  String? _errorMessage;
  bool _isMiniPlayerVisible = false;
  bool _isPlayerExpanded = false;
  bool _isShuffling = false;
  LoopMode _loopMode = LoopMode.off;

  // Getters
  AudioPlayer get player => _player;
  List<Song> get searchResults => _searchResults;
  List<Song> get queue => _queue;
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isShuffling => _isShuffling;
  LoopMode get loopMode => _loopMode;
  bool get isFetchingMore => _isFetchingMore;
  bool get isLoadingSong => _isLoadingSong;
  String? get errorMessage => _errorMessage;

  MusicProvider() {
    _initAudioSession();
    _setupPlayerListeners();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompletion();
      }
      notifyListeners();
    });

    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('PLAYER STREAM ERROR: $e');
      _errorMessage = "Playback error. Trying next track...";
      notifyListeners();
      // Auto-skip on stream error
      if (_queue.isNotEmpty) {
        _safeNext();
      }
    });
  }

  // ====================================================================
  // 6. SEARCH FUNCTIONALITY
  // ====================================================================

  Future<void> search(String query) async {
    _currentQuery = query;
    _searchResults.clear();
    _nextPageToken = null;
    notifyListeners();
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (_isFetchingMore || _nextPageToken == null) return;
    _isFetchingMore = true;
    notifyListeners();
    await _fetchPage();
    _isFetchingMore = false;
    notifyListeners();
  }

  Future<void> _fetchPage() async {
    try {
      String url =
          'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$_currentQuery&type=video,playlist&maxResults=20&key=$_apiKey';
      if (_nextPageToken != null) url += "&pageToken=$_nextPageToken";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _nextPageToken = data['nextPageToken'];
        List<dynamic> items = data['items'];

        List<Song> newResults = items.map((item) {
          var snippet = item['snippet'];
          var thumbs = snippet['thumbnails'];

          String img = "";
          if (thumbs != null) {
            if (thumbs.containsKey('maxres')) {
              img = thumbs['maxres']['url'];
            } else if (thumbs.containsKey('high')) {
              img = thumbs['high']['url'];
            } else if (thumbs.containsKey('medium')) {
              img = thumbs['medium']['url'];
            } else {
              img = thumbs['default']['url'];
            }
          }

          String id = item['id']['videoId'] ?? item['id']['playlistId'];
          String kind = item['id']['kind'] == "youtube#playlist"
              ? 'playlist'
              : 'video';

          return Song(
            id: id,
            title: snippet['title'] ?? "Unknown Title",
            artist: snippet['channelTitle'] ?? "Unknown Artist",
            thumbUrl: img,
            type: kind,
          );
        }).toList();

        _searchResults.addAll(newResults);
        notifyListeners();
      }
    } catch (e) {
      print("Network Error during search: $e");
      _errorMessage = "Search failed. Check connection.";
      notifyListeners();
    }
  }

  // ====================================================================
  // 7. CORE PLAYBACK ENGINE
  // ====================================================================

  Future<void> play(Song song) async {
    await _player.stop();
    _queue = [song];
    _currentIndex = 0;
    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    _errorMessage = null;
    await _loadAndPlayCurrent();
  }

  Future<void> playPlaylist(Song album) async {
    await _player.stop();
    _isMiniPlayerVisible = true;
    _isLoadingSong = true;
    notifyListeners();

    try {
      var playlist = await _yt.playlists.get(yt.PlaylistId(album.id));
      var videos = _yt.playlists.getVideos(playlist.id);

      List<Song> albumSongs = [];
      await for (var video in videos) {
        albumSongs.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          thumbUrl: video.thumbnails.highResUrl,
          type: 'video',
        ));
        if (albumSongs.length >= 50) break;
      }

      if (albumSongs.isNotEmpty) {
        _queue = albumSongs;
        _currentIndex = 0;
        _isPlayerExpanded = true;
        await _loadAndPlayCurrent();
      } else {
        _isLoadingSong = false;
        _errorMessage = "Playlist empty.";
        notifyListeners();
      }
    } catch (e) {
      _isLoadingSong = false;
      _errorMessage = "Could not load playlist.";
      notifyListeners();
    }
  }

  Future<void> _loadAndPlayCurrent() async {
    if (_queue.isEmpty || _currentIndex < 0) return;

    _isLoadingSong = true;
    _errorMessage = null;
    notifyListeners();

    final song = _queue[_currentIndex];
    print('Loading song: ${song.title} (${song.id})');

    try {
      // 1. Get manifest with retry logic (THE MAGIC FIX)
      yt.StreamManifest? manifest =
          await _getManifestWithRetry(song.id, maxAttempts: 3);

      if (manifest == null) {
        throw Exception('No manifest retrieved.');
      }

      // 2. Select best audio stream
      yt.AudioOnlyStreamInfo? audioStream = _getBestAudioStream(manifest);
      if (audioStream == null) {
        throw Exception('No audio stream found.');
      }

      print(
          'Selected stream: ${audioStream.bitrate} bitrate, ${audioStream.container.name}');

      // 3. Create audio source with metadata
      final source = AudioSource.uri(
        audioStream.url,
        tag: MediaItem(
          id: song.id,
          album: "OXCY Music",
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.thumbUrl),
        ),
      );

      // 4. Load and play
      await _player.setAudioSource(source);
      _player.play();

      _isLoadingSong = false;
      notifyListeners();
    } catch (e, stackTrace) {
      print('CRITICAL PLAYBACK ERROR: $e');
      print(stackTrace);
      _isLoadingSong = false;
      _errorMessage = "Cannot play this track. It may be restricted.";
      notifyListeners();

      // Auto-skip to next track after a short delay
      await Future.delayed(const Duration(seconds: 2));
      if (_queue.isNotEmpty) {
        _safeNext();
      }
    }
  }

  void _handleTrackCompletion() {
    if (_loopMode == LoopMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else if (_loopMode == LoopMode.all) {
      _safeNext();
    } else {
      _safeNext();
    }
  }

  Future<void> _safeNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      // End of queue
      if (_loopMode == LoopMode.all) {
        _currentIndex = 0;
      } else {
        await _player.stop();
        _isMiniPlayerVisible = false;
        notifyListeners();
        return;
      }
    }
    await _loadAndPlayCurrent();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }
    await _loadAndPlayCurrent();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _loadAndPlayCurrent();
    }
  }

  // ====================================================================
  // 8. UI CONTROLS
  // ====================================================================

  void togglePlayerView() {
    _isPlayerExpanded = !_isPlayerExpanded;
    notifyListeners();
  }

  void collapsePlayer() {
    _isPlayerExpanded = false;
    notifyListeners();
  }

  void togglePlayPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void toggleShuffle() {
    _isShuffling = !_isShuffling;
    if (_isShuffling) {
      // Keep current song first if playing
      if (_currentIndex > 0) {
        Song current = _queue[_currentIndex];
        List<Song> others = List.from(_queue)..removeAt(_currentIndex);
        others.shuffle();
        _queue = [current] + others;
        _currentIndex = 0;
      } else {
        _queue.shuffle();
      }
    }
    notifyListeners();
  }

  void toggleLoop() async {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.one;
      await _player.setLoopMode(LoopMode.one);
    } else if (_loopMode == LoopMode.one) {
      _loopMode = LoopMode.all;
      await _player.setLoopMode(LoopMode.all);
    } else {
      _loopMode = LoopMode.off;
      await _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void addToQueue(Song song) {
    _queue.add(song);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      // Adjust current index if removing current or before current
      if (index == _currentIndex) {
        // If removing current song, stop playback
        _player.stop();
        _queue.removeAt(index);
        if (_currentIndex >= _queue.length) {
          _currentIndex = _queue.isEmpty ? -1 : _queue.length - 1;
        }
        if (_currentIndex >= 0) {
          _loadAndPlayCurrent();
        }
      } else if (index < _currentIndex) {
        _currentIndex--;
        _queue.removeAt(index);
      } else {
        _queue.removeAt(index);
      }
      notifyListeners();
    }
  }

  // Cleanup
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
