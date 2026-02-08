import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Required for pow
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

// ====================================================================
// DATA MODEL
// ====================================================================

class Song {
  final String id;        // YouTube ID or Local File Path
  final String title;
  final String artist;
  final String thumbUrl;  // URL for YouTube, or Empty for Local
  final String type;      // 'video', 'playlist', or 'local'
  final int? localId;     // For fetching local album art

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    this.type = 'video',
    this.localId,
  });
}

// ====================================================================
// MUSIC PROVIDER (MERGED ENGINE)
// ====================================================================

class MusicProvider with ChangeNotifier {
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";
  
  final _player = AudioPlayer();
  final _yt = yt.YoutubeExplode(); 
  final _audioQuery = OnAudioQuery();

  // Lists
  List<Song> _searchResults = [];
  List<Song> _localSongs = [];
  List<Song> _queue = [];
  
  // State
  int _currentIndex = -1;
  String? _nextPageToken;
  String _currentQuery = "";
  bool _isFetchingMore = false; // RESTORED
  bool _isLoadingSong = false;
  bool _isFetchingLocal = false;
  String? _errorMessage;
  
  // Player State
  bool _isMiniPlayerVisible = false;
  bool _isPlayerExpanded = false;
  bool _isShuffling = false; // RESTORED
  LoopMode _loopMode = LoopMode.off; // RESTORED

  // Getters
  AudioPlayer get player => _player;
  List<Song> get searchResults => _searchResults;
  List<Song> get localSongs => _localSongs;
  List<Song> get queue => _queue;
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) 
      ? _queue[_currentIndex] 
      : null;
      
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isShuffling => _isShuffling;
  LoopMode get loopMode => _loopMode;
  bool get isLoadingSong => _isLoadingSong;
  bool get isFetchingMore => _isFetchingMore; // RESTORED
  bool get isFetchingLocal => _isFetchingLocal;
  String? get errorMessage => _errorMessage;

  MusicProvider() {
    _initAudioSession();
    _setupPlayerListeners();
    fetchLocalSongs(); // Auto-load local music
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      notifyListeners();
    });

    _player.playbackEventStream.listen((event) {}, 
      onError: (Object e, StackTrace stackTrace) {
      print('PLAYER STREAM ERROR: $e');
      _errorMessage = "Playback Error. Skipping...";
      notifyListeners();
      Timer(const Duration(seconds: 3), () {
        if (_queue.isNotEmpty) next();
      });
    });
  }

  // ====================================================================
  // 1. LOCAL AUDIO LOGIC
  // ====================================================================

  Future<void> fetchLocalSongs() async {
    _isFetchingLocal = true;
    notifyListeners();

    try {
      if (await Permission.audio.request().isGranted || 
          await Permission.storage.request().isGranted) {
        
        List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        _localSongs = songs.map((item) {
          return Song(
            id: item.data, // File Path
            title: item.title,
            artist: item.artist ?? "Unknown Artist",
            thumbUrl: "", 
            type: 'local',
            localId: item.id,
          );
        }).toList();
      }
    } catch (e) {
      print("Local Fetch Error: $e");
    }

    _isFetchingLocal = false;
    notifyListeners();
  }

  // ====================================================================
  // 2. STREAMING SEARCH & PAGINATION (RESTORED)
  // ====================================================================

  Future<void> search(String query) async {
    _currentQuery = query;
    _searchResults = [];
    _nextPageToken = null;
    notifyListeners();
    await _fetchPage();
  }

  // RESTORED: loadMore method
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

  // ====================================================================
  // 3. UNIFIED PLAYBACK LOGIC (RESTORED & MERGED)
  // ====================================================================

  // RESTORED: play(Song) - Handles both Local and Stream
  Future<void> play(Song song) async {
    await _player.stop();
    
    // If local, set queue to all local songs for continuous play
    if (song.type == 'local') {
      _queue = _localSongs;
      _currentIndex = _localSongs.indexOf(song);
    } else {
      // If stream, just play this one (queueing logic can be expanded)
      _queue = [song];
      _currentIndex = 0;
    }

    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    _errorMessage = null;
    
    await _loadAndPlayCurrent();
  }

  // RESTORED: playPlaylist(Song)
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
      // CASE 1: LOCAL MUSIC
      if (song.type == 'local') {
        print('Playing Local File: ${song.id}');
        final source = AudioSource.uri(
          Uri.parse(song.id),
          tag: MediaItem(
            id: song.localId.toString(),
            album: "Local Music",
            title: song.title,
            artist: song.artist,
          ),
        );
        await _player.setAudioSource(source);
        _player.play();
      } 
      // CASE 2: STREAMING (Use Proxy-First Logic)
      else {
        print('Fetching Stream URL for: ${song.title}');
        final streamUrl = await _getStreamUrl(song.id);
        
        if (streamUrl == null) throw Exception("No stream found.");

        final source = AudioSource.uri(
          Uri.parse(streamUrl),
          headers: {
             'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          },
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
      }
      
      _isLoadingSong = false;
      notifyListeners();

    } catch (e) {
      print("Playback Error: $e");
      _isLoadingSong = false;
      _errorMessage = "Playback Failed.";
      notifyListeners();
      Timer(const Duration(seconds: 2), () {
        if (_queue.isNotEmpty) next();
      });
    }
  }

  // --- STREAM EXTRACTOR (Lemnos/Cobalt) ---
  Future<String?> _getStreamUrl(String videoId) async {
    try {
      // Lemnos
      final response = await http.get(Uri.parse('https://yt.lemnoslife.com/videos?part=streaming&id=$videoId')).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
           final streamingData = data['items'][0]['streamingData'];
           if (streamingData != null) {
              List<dynamic> formats = [];
              if (streamingData['formats'] != null) formats.addAll(streamingData['formats']);
              if (streamingData['adaptiveFormats'] != null) formats.addAll(streamingData['adaptiveFormats']);
              
              var audio = formats.firstWhere((f) => f['mimeType'].toString().contains('audio/mp4'), orElse: () => null);
              audio ??= formats.firstWhere((f) => f['mimeType'].toString().contains('audio'), orElse: () => null);
              
              if (audio != null) return audio['url'];
           }
        }
      }
    } catch (e) { print(e); }

    try {
      // Cobalt
      final response = await http.post(
        Uri.parse('https://cobalt.gamemonk.net/api/json'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'url': 'https://www.youtube.com/watch?v=$videoId', 'isAudioOnly': true})
      ).timeout(const Duration(seconds: 4));
      final data = json.decode(response.body);
      if (data['url'] != null) return data['url'];
    } catch (e) { print(e); }

    return null;
  }

  // ====================================================================
  // 4. CONTROLS (RESTORED)
  // ====================================================================

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      if (_loopMode == LoopMode.all) _currentIndex = 0;
      else { await _player.stop(); _isMiniPlayerVisible = false; notifyListeners(); return; }
    }
    await _loadAndPlayCurrent();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) await _player.seek(Duration.zero);
    else if (_currentIndex > 0) { _currentIndex--; await _loadAndPlayCurrent(); }
  }

  // RESTORED: Toggle Shuffle
  void toggleShuffle() {
    _isShuffling = !_isShuffling;
    if (_isShuffling) {
      if (_currentIndex > 0) {
        Song current = _queue[_currentIndex];
        List<Song> others = List.from(_queue)..removeAt(_currentIndex);
        others.shuffle();
        _queue = [current] + others;
        _currentIndex = 0;
      } else {
        _queue.shuffle();
      }
    } else {
      // Note: Unshuffling accurately requires saving original list, 
      // but for now we just toggle the flag.
      if (currentSong?.type == 'local') {
         _queue = List.from(_localSongs);
         if (currentSong != null) _currentIndex = _queue.indexWhere((s) => s.id == currentSong!.id);
      }
    }
    notifyListeners();
  }

  // RESTORED: Toggle Loop
  void toggleLoop() async { 
    if (_loopMode == LoopMode.off) { _loopMode = LoopMode.one; await _player.setLoopMode(LoopMode.one); }
    else if (_loopMode == LoopMode.one) { _loopMode = LoopMode.all; await _player.setLoopMode(LoopMode.all); }
    else { _loopMode = LoopMode.off; await _player.setLoopMode(LoopMode.off); }
    notifyListeners(); 
  }

  void togglePlayerView() { _isPlayerExpanded = !_isPlayerExpanded; notifyListeners(); }
  void collapsePlayer() { _isPlayerExpanded = false; notifyListeners(); }
  void togglePlayPause() { if (_player.playing) _player.pause(); else _player.play(); }
  void clearError() { _errorMessage = null; notifyListeners(); }
  void dispose() { _player.dispose(); super.dispose(); }
}
