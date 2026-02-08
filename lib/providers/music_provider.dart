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
// 1. AGGRESSIVE CUSTOM HTTP CLIENT
// ====================================================================

class AggressiveHttpClient extends yt.HttpClient {
  final _client = http.Client();
  final List<Map<String, String>> _headersPool = [
    // Samsung S22 (Android 13)
    {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Origin': 'https://www.youtube.com',
      'Referer': 'https://www.youtube.com/',
    },
    // Windows 10 Chrome
    {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'X-YouTube-Client-Name': '1',
      'X-YouTube-Client-Version': '2.20231219.09.00',
      'Origin': 'https://www.youtube.com',
    },
    // Older Android (Robust)
    {
      'User-Agent': 'com.google.android.youtube/17.36.4 (Linux; U; Android 11) gzip',
      'Accept': '*/*',
      'X-YouTube-Client-Name': '3',
      'X-YouTube-Client-Version': '17.36.4',
    },
  ];

  @override
  Future<yt.HttpClientResponse> get(Uri url, {Map<String, String>? headers}) async {
    final random = Random();
    final chosenHeaders = _headersPool[random.nextInt(_headersPool.length)];
    
    final requestHeaders = {
      ...chosenHeaders,
      ...(headers ?? {}),
    };
    
    final request = http.Request('GET', url);
    request.headers.addAll(requestHeaders);
    
    final streamedResponse = await _client.send(request);
    return yt.HttpClientResponse(
      streamedResponse.statusCode,
      streamedResponse.headers,
      streamedResponse.stream.transform(utf8.decoder),
    );
  }

  @override
  Future<yt.HttpClientResponse> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final random = Random();
    final chosenHeaders = _headersPool[random.nextInt(_headersPool.length)];
    
    final requestHeaders = {
      ...chosenHeaders,
      ...(headers ?? {}),
    };
    
    final request = http.Request('POST', url);
    request.headers.addAll(requestHeaders);
    if (body != null) {
      request.body = body.toString();
    }
    
    final streamedResponse = await _client.send(request);
    return yt.HttpClientResponse(
      streamedResponse.statusCode,
      streamedResponse.headers,
      streamedResponse.stream.transform(utf8.decoder),
    );
  }

  @override
  void close() {
    _client.close();
  }
}

// ====================================================================
// 2. SUPER CHARGED CLIENT POOL
// ====================================================================

final List<yt.YoutubeApiClient> _aryaClientPool = [
  // Android TestSuite (The "Golden Key" - 100% Success)
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

  // Web Creator (Most reliable)
  yt.YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'WEB_CREATOR',
        'clientVersion': '1.20231219',
        'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'osName': 'Windows',
        'osVersion': '10.0',
      },
      'contextClientName': 62,
      'requireJsPlayer': true,
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),

  // Android VR (Backup)
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

  // iOS Music (Audio-focused)
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
// 3. MULTI-TIER STREAM EXTRACTION
// ====================================================================

Future<yt.StreamManifest?> _getManifestAggressive(String videoId, {int maxRetries = 3}) async {
  // Use our aggressive HTTP client
  final httpClient = AggressiveHttpClient();
  final ytInstance = yt.YoutubeExplode(httpClient);
  
  Exception? lastError;
  
  for (int retry = 0; retry < maxRetries; retry++) {
    for (var client in _aryaClientPool) {
      try {
        print('🔄 Attempt $retry: Switching Client...');
        
        final manifest = await ytInstance.videos.streamsClient.getManifest(
          videoId,
          ytClients: [client],
        );
        
        if (manifest.audioOnly.isNotEmpty) {
          print('✅ Success! Manifest found.');
          httpClient.close();
          return manifest;
        }
      } catch (e) {
        lastError = e as Exception;
        print('❌ Client attempt failed: $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    // Exponential backoff
    await Future.delayed(Duration(seconds: pow(2, retry).toInt()));
  }
  
  httpClient.close();
  throw lastError ?? Exception('All extraction methods failed');
}

// ====================================================================
// 4. FALLBACK EXTRACTION (BACKDOORS)
// ====================================================================

Future<Uri?> _getDirectStreamUrl(String videoId) async {
  // Method 1: LemnosLife (Dedicated Unblocker)
  try {
    print("Trying LemnosLife Fallback...");
    final response = await http.get(
      Uri.parse('https://yt.lemnoslife.com/videos?part=streaming&id=$videoId'),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(const Duration(seconds: 4));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List;
      if (items.isNotEmpty) {
        final streamingData = items[0]['streamingData'];
        if (streamingData != null) {
          final formats = streamingData['formats'] as List?;
          final adaptiveFormats = streamingData['adaptiveFormats'] as List?;
          
          final allFormats = [
            if (formats != null) ...formats,
            if (adaptiveFormats != null) ...adaptiveFormats,
          ];
          
          // Find audio-only streams
          for (var format in allFormats) {
            final mimeType = format['mimeType'] as String?;
            if (mimeType?.contains('audio/mp4') ?? false) {
              final url = format['url'] as String?;
              if (url != null) return Uri.parse(url);
            }
          }
        }
      }
    }
  } catch (e) { print("Lemnos Failed: $e"); }
  
  // Method 2: Piped API (Decentralized)
  try {
    print("Trying Piped Fallback...");
    final response = await http.get(
      Uri.parse('https://pipedapi.kavin.rocks/streams/$videoId'),
    ).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final audioStreams = data['audioStreams'] as List?;
      if (audioStreams != null && audioStreams.isNotEmpty) {
        return Uri.parse(audioStreams.first['url'] as String);
      }
    }
  } catch (e) { print("Piped Failed: $e"); }
  
  return null;
}

// ====================================================================
// 5. HYBRID STREAM GETTER
// ====================================================================

Future<AudioSource> _getAudioSource(String videoId, Song song) async {
  // Try Hemant's Engine first
  try {
    final manifest = await _getManifestAggressive(videoId);
    final audioStream = manifest!.audioOnly.withHighestBitrate();
    print('🎵 Using Hemant Engine: ${audioStream.bitrate}');
    
    return AudioSource.uri(
      audioStream.url,
      tag: MediaItem(
        id: song.id,
        album: "OXCY Music",
        title: song.title,
        artist: song.artist,
        artUri: Uri.parse(song.thumbUrl),
      ),
    );
  } catch (e) {
    print('⚠️ Engine failed ($e). Engaging Backdoors...');
    
    // Fallback to direct extraction (Lemnos/Piped)
    final directUrl = await _getDirectStreamUrl(videoId);
    if (directUrl != null) {
      print('🎵 Using Backdoor stream');
      return AudioSource.uri(
        directUrl,
        tag: MediaItem(
          id: song.id,
          album: "OXCY Music",
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.thumbUrl),
        ),
      );
    }
    
    throw Exception('No playable stream found');
  }
}

// ====================================================================
// 6. MAIN MUSIC PROVIDER
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

class MusicProvider with ChangeNotifier {
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";
  
  final AudioPlayer _player = AudioPlayer();
  final List<Song> _searchResults = [];
  final List<Song> _queue = [];
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
      print('Player error: $e');
      _errorMessage = "Playback error. Skipping...";
      notifyListeners();
      Timer(const Duration(seconds: 2), () {
        if (_queue.isNotEmpty) _safeNext();
      });
    });
  }

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
      print("Search error: $e");
    }
  }

  Future<void> playPlaylist(Song album) async {
    await _player.stop();
    _isMiniPlayerVisible = true;
    _isLoadingSong = true;
    notifyListeners();

    try {
      final ytInstance = yt.YoutubeExplode(); // Use default for metadata
      var playlist = await ytInstance.playlists.get(yt.PlaylistId(album.id));
      var videos = ytInstance.playlists.getVideos(playlist.id);

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
      ytInstance.close();

      if (albumSongs.isNotEmpty) {
        _queue = albumSongs;
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

  Future<void> play(Song song) async {
    await _player.stop();
    _queue = [song];
    _currentIndex = 0;
    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    _errorMessage = null;
    await _loadAndPlayCurrent();
  }

  Future<void> _loadAndPlayCurrent() async {
    if (_queue.isEmpty || _currentIndex < 0) return;

    final song = _queue[_currentIndex];
    _isLoadingSong = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🎯 Loading: ${song.title}');
      
      final source = await _getAudioSource(song.id, song);
      await _player.setAudioSource(source);
      _player.play();
      
      _isLoadingSong = false;
      notifyListeners();
      
    } catch (e) {
      print('💥 Playback failed: $e');
      _isLoadingSong = false;
      _errorMessage = "Could not play. Try again.";
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
