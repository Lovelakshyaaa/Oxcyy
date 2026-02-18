import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:oxcy/models/search_models.dart';

class MusicProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final String _baseUrl = "https://music-three-woad.vercel.app";

  Song? _currentSong;
  Song? get currentSong => _currentSong;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  Duration _position = Duration.zero;
  Duration get position => _position;
  
  // --- RESTORED UI AND LOCAL STATE ---
  bool _isPlayerExpanded = false;
  bool get isPlayerExpanded => _isPlayerExpanded;

  List<AlbumModel> _localAlbums = [];
  List<AlbumModel> get localAlbums => _localAlbums;

  bool _isFetchingLocal = false;
  bool get isFetchingLocal => _isFetchingLocal;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _loadingSongId;
  String? get loadingSongId => _loadingSongId;

  LoopMode _repeatMode = LoopMode.off;
  LoopMode get repeatMode => _repeatMode;

  bool _isShuffleEnabled = false;
  bool get isShuffleEnabled => _isShuffleEnabled;
  // --- END RESTORED STATE ---


  MusicProvider() {
    _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      if (playerState.processingState == ProcessingState.completed) {
        _position = Duration.zero;
        _isPlaying = false;
      }
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });

    _audioPlayer.loopModeStream.listen((mode) {
        _repeatMode = mode;
        notifyListeners();
    });

    _audioPlayer.shuffleModeEnabledStream.listen((enabled) {
        _isShuffleEnabled = enabled;
        notifyListeners();
    });
  }

  Future<void> play(Song song, {List<Song>? newQueue}) async {
    _loadingSongId = song.id;
    notifyListeners();

    try {
      if (song.downloadUrl == null || song.downloadUrl!.isEmpty) {
        final response = await http.get(Uri.parse('$_baseUrl/song?id=${song.id}'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body)['data'];
          final songData = data is List ? data[0] : data;
          final downloadUrl = _getDownloadUrl(songData['downloadUrl']);

          if (downloadUrl != null) {
            song.downloadUrl = downloadUrl;
          } else {
             _setError('Playback error: Could not find a playable URL.');
            return;
          }
        } else {
          _setError('Network error fetching song details.');
          return;
        }
      }

      if (song.downloadUrl != null) {
        await _audioPlayer.setUrl(song.downloadUrl!);
        _currentSong = song;
        _audioPlayer.play();
      }
    } catch (e) {
      _setError("Error during playback setup: $e");
    } finally {
      _loadingSongId = null;
      notifyListeners();
    }
  }
  
  // --- RESTORED METHODS ---
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchLocalMusic() async {
    bool permissionGranted = await _audioQuery.permissionsStatus();
    if (!permissionGranted) {
      permissionGranted = await _audioQuery.permissionsRequest();
    }
    if (!permissionGranted) {
      _setError("Storage permission not granted.");
      return;
    }

    _isFetchingLocal = true;
    notifyListeners();
    try {
      _localAlbums = await _audioQuery.queryAlbums();
    } catch (e) {
      _setError("Failed to fetch local music: $e");
    } finally {
      _isFetchingLocal = false;
      notifyListeners();
    }
  }

  Future<List<SongModel>> getLocalSongsByAlbum(int albumId) async {
    return await _audioQuery.querySongs(albumId: albumId, sortType: SongSortType.TRACK);
  }

  Future<Uint8List?> getArtwork(int id, ArtworkType type) async {
    return await _audioQuery.queryArtwork(id, type);
  }

  void togglePlayerView() {
    _isPlayerExpanded = !_isPlayerExpanded;
    notifyListeners();
  }

  void collapsePlayer() {
    _isPlayerExpanded = false;
    notifyListeners();
  }
  
  void cycleRepeatMode() {
    if (_repeatMode == LoopMode.off) {
      _audioPlayer.setLoopMode(LoopMode.one);
    } else if (_repeatMode == LoopMode.one) {
      _audioPlayer.setLoopMode(LoopMode.all);
    } else {
      _audioPlayer.setLoopMode(LoopMode.off);
    }
  }

  void toggleShuffle() {
    _audioPlayer.setShuffleModeEnabled(!_isShuffleEnabled);
  }

  // --- END RESTORED METHODS ---

  String? _getDownloadUrl(dynamic urlField) {
    if (urlField is List && urlField.isNotEmpty) {
      return urlField.last['link'];
    }
    if (urlField is String) {
      return urlField;
    }
    return null;
  }

  void pause() {
    _audioPlayer.pause();
  }

  void resume() {
    _audioPlayer.play();
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  @override
  void dispose() {
    _audio_player.dispose();
    super.dispose();
  }
}
