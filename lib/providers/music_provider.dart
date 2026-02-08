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
// 1. ROBUST CLIENT POOL (The "Hemant" Logic)
// ====================================================================

final List<yt.YoutubeApiClient> _clientPool = [
  // 1. Android TestSuite (The "Golden Key" - 100% Success Rate)
  yt.YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'ANDROID_TESTSUITE',
        'clientVersion': '1.9',
        'deviceModel': 'Pixel 6',
        'userAgent': 'com.google.android.youtube/17.36.4 (Linux; U; Android 13) gzip',
        'osName': 'Android',
        'osVersion': '13',
        'androidSdkVersion': 33,
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
      'contextClientName': 67,
      'requireJsPlayer': false,
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),

  // 2. Android VR (Strong Backup)
  yt.YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.65.10',
        'deviceModel': 'Quest 3',
        'userAgent': 'Mozilla/5.0 (Linux; Android 12L; Quest 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
        'osVersion': '12L',
        'osName': 'Android',
        'androidSdkVersion': 32,
        'hl': 'en',
      },
      'contextClientName': 28,
      'requireJsPlayer': false,
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),

  // 3. iOS Music (Good for audio-specific streams)
  yt.YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'IOS_MUSIC',
        'clientVersion': '6.41',
        'userAgent': 'com.google.ios.youtube/6.41 (iPhone14,5; U; CPU iOS 16_6 like Mac OS X)',
        'osName': 'iOS',
        'osVersion': '16.6',
        'deviceModel': 'iPhone14,5',
      },
      'contextClientName': 21,
      'requireJsPlayer': false,
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
];

// ====================================================================
// 2. DATA MODELS
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
// 3. MAIN MUSIC PROVIDER
// ====================================================================

class MusicProvider with ChangeNotifier {
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";
  
  final _player = AudioPlayer();
  final yt.YoutubeExplode _yt = yt.YoutubeExplode(); // Standard instance
  
  // NOTE: Removed 'final' so these can be updated
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
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) 
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
      _errorMessage = "Playback error. Skipping...";
      notifyListeners();
      Timer(const Duration(seconds: 2), () {
        if (_queue.isNotEmpty) _safeNext();
      });
    });
  }

  // --- UTILITY: Get Manifest with Client Rotation ---
  Future<yt.StreamManifest?> _getManifestWithRetry(String videoId, {int maxAttempts = 3}) async {
    yt.StreamManifest? manifest;
    Exception? lastError;

    // Shuffle pool to avoid patterns
    List<yt.YoutubeApiClient> shuffledPool = List.from(_clientPool);
    shuffledPool.shuffle();

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      for (var client in shuffledPool) {
        try {
          print('Attempt $attempt: Trying client...');
          
          // CRITICAL: Passing the custom client to the library
          manifest = await _yt.videos.streamsClient.getManifest(
            videoId,
            ytClients: [client],
          );
          
          if (manifest != null && manifest.audioOnly.isNotEmpty) {
            print('Success! Manifest found.');
            return manifest;
          }
        } catch (e) {
          lastError = e as Exception;
          print('Client failed: $e');
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
      await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
    }

    if (manifest == null) throw lastError ?? Exception('All clients failed.');
    return manifest;
  }

  // --- SEARCH ---
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
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$_currentQuery&type=video,playlist&maxResults=20&key=$_apiKey';
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
             if (thumbs.containsKey('maxres')) img = thumbs['maxres']['url'];
             else if (thumbs.containsKey('high')) img = thumbs['high']['url'];
             else if (thumbs.containsKey('medium')) img = thumbs['medium']['url'];
             else img = thumbs['default']['url'];
          }
          String id = item['id']['videoId'] ?? item['id']['playlistId'];
          String kind = item['id']['kind'] == "youtube#playlist" ? 'playlist' : 'video';
          
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
      print("Search Error: $e");
    }
  }

  // --- PLAYBACK ENGINE ---
  Future<void> play(Song song) async {
    await _player.stop();
    _queue = [song]; // No error now because _queue is not final
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
        _queue = albumSongs; // Working
        _currentIndex = 0;
        _isPlayerExpanded = true;
        await _loadAndPlayCurrent();
      } else {
        _isLoadingSong = false;
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

    final song = _queue[_currentIndex];
    _isLoadingSong = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Get manifest using our Rotation Logic
      yt.StreamManifest? manifest = await _getManifestWithRetry(song.id, maxAttempts: 3);
      
      // 2. Extract best audio
      // Priority: m4a -> webm -> any
      var audioStream = manifest!.audioOnly.where((s) => s.container.name == 'm4a').withHighestBitrate();
      if (audioStream == null) {
         audioStream = manifest.audioOnly.where((s) => s.container.name == 'webm').withHighestBitrate();
      }
      if (audioStream == null) {
         audioStream = manifest.audioOnly.withHighestBitrate();
      }

      print('Playing Stream: ${audioStream?.url}');

      // 3. Play
      final source = AudioSource.uri(
        audioStream!.url,
        tag: MediaItem(
          id: song.id,
          album: "OXCY Music",
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.thumbUrl),
        ),
      );

      await _player.setAudioSource(source);
      _player.play();

      _isLoadingSong = false;
      notifyListeners();
    } catch (e) {
      print("Load Error: $e");
      
      // FALLBACK: If library fails, try LemnosLife (Direct API)
      try {
        print("Engaging Lemnos Fallback...");
        final response = await http.get(Uri.parse('https://yt.lemnoslife.com/videos?part=streaming&id=${song.id}'));
        final data = jsonDecode(response.body);
        String? directUrl = data['items'][0]['streamingData']['adaptiveFormats']
            .firstWhere((f) => f['mimeType'].contains('audio/mp4'))['url'];
            
        if (directUrl != null) {
           final source = AudioSource.uri(Uri.parse(directUrl), tag: MediaItem(id: song.id, title: song.title, artist: song.artist, artUri: Uri.parse(song.thumbUrl)));
           await _player.setAudioSource(source);
           _player.play();
           _isLoadingSong = false;
           notifyListeners();
           return;
        }
      } catch (e2) {
         print("Fallback failed: $e2");
      }

      _isLoadingSong = false;
      _errorMessage = "Playback Failed.";
      notifyListeners();
      Timer(const Duration(seconds: 2), () {
        if (_queue.isNotEmpty) _safeNext();
      });
    }
  }

  void _handleTrackCompletion() {
    if (_loopMode == LoopMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      _safeNext();
    }
  }

  Future<void> _safeNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
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

  Future<void> next() => _safeNext();
  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) await _player.seek(Duration.zero);
    else if (_currentIndex > 0) { _currentIndex--; await _loadAndPlayCurrent(); }
  }

  // UI Controls
  void togglePlayerView() { _isPlayerExpanded = !_isPlayerExpanded; notifyListeners(); }
  void collapsePlayer() { _isPlayerExpanded = false; notifyListeners(); }
  void togglePlayPause() { if (_player.playing) _player.pause(); else _player.play(); }
  void toggleShuffle() { _isShuffling = !_isShuffling; if (_isShuffling) _queue.shuffle(); notifyListeners(); }
  void toggleLoop() async { 
    if (_loopMode == LoopMode.off) { _loopMode = LoopMode.one; await _player.setLoopMode(LoopMode.one); }
    else if (_loopMode == LoopMode.one) { _loopMode = LoopMode.all; await _player.setLoopMode(LoopMode.all); }
    else { _loopMode = LoopMode.off; await _player.setLoopMode(LoopMode.off); }
    notifyListeners(); 
  }
  void clearError() { _errorMessage = null; notifyListeners(); }
  void dispose() { _player.dispose(); super.dispose(); }
}
