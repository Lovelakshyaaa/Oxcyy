import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:oxcy/services/audio_handler.dart';

// Represents a single song, abstracting over local and Saavn sources.
class Song {
  final String id; // Stream URL for Saavn, file URI for local
  final String title;
  final String artist;
  final String thumbUrl;
  final String type;
  final int? localId;
  final int? albumId;
  final Duration? duration;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    required this.type,
    this.localId,
    this.albumId,
    this.duration,
  });
}

// Manages the application's music state, including search, playback, and local files.
class MusicProvider with ChangeNotifier {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  AudioHandler? _audioHandler;
  AudioHandler? get audioHandler => _audioHandler;

  final Map<String, Uint8List> _artworkCache = {};

  List<Song> _searchResults = [];
  List<Song> get searchResults => _searchResults;

  List<AlbumModel> _localAlbums = [];
  List<AlbumModel> get localAlbums => _localAlbums;

  List<Song> _localSongs = [];
  List<Song> get localSongs => _localSongs;

  List<Song> _shuffledSongs = [];

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String? _loadingSongId;
  String? get loadingSongId => _loadingSongId;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isFetchingLocal = true;
  bool get isFetchingLocal => _isFetchingLocal;

  bool _isPlayerExpanded = false;
  bool get isPlayerExpanded => _isPlayerExpanded;

  bool _isShuffleEnabled = false;
  bool get isShuffleEnabled => _isShuffleEnabled;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceRepeatMode get repeatMode => _repeatMode;

  MusicProvider() {
    _init();
  }

  Future<void> _init() async {
    _audioHandler = await initAudioService();
    _audioHandler?.playbackState.listen((playbackState) {
      if (_repeatMode != playbackState.repeatMode) {
        _repeatMode = playbackState.repeatMode;
        notifyListeners();
      }
    });
    fetchLocalMusic();
  }

  void clearError() {
    _errorMessage = null;
  }

  Future<void> fetchLocalMusic() async {
    _isFetchingLocal = true;
    notifyListeners();

    try {
      if (await Permission.audio.request().isGranted ||
          await Permission.storage.request().isGranted) {
        List<AlbumModel> albums = await _audioQuery.queryAlbums(
          sortType: AlbumSortType.ALBUM,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        _localAlbums = albums;
        _localSongs = songs
            .where((s) => (s.isMusic ?? false) && (s.duration ?? 0) > 10000)
            .map((s) => Song(
                  id: s.uri!,
                  title: s.title,
                  artist: s.artist ?? "Unknown",
                  thumbUrl: "",
                  type: 'local',
                  localId: s.id,
                  albumId: s.albumId,
                  duration: Duration(milliseconds: s.duration ?? 0),
                ))
            .toList();

        _shuffledSongs = List.from(_localSongs)..shuffle();

        if (_audioHandler != null) {
          await _updateQueueWithSongs(
              _isShuffleEnabled ? _shuffledSongs : _localSongs);
        }
      }
    } catch (e) {
      print("Error fetching local music: $e");
      _errorMessage = "Error fetching local music.";
      notifyListeners();
    } finally {
      _isFetchingLocal = false;
      notifyListeners();
    }
  }

  Future<List<Song>> getLocalSongsByAlbum(int albumId) async {
    List<SongModel> albumSongs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      albumId,
      orderType: OrderType.ASC_OR_SMALLER,
    );

    albumSongs.sort((a, b) {
      int trackA = int.tryParse(a.track.toString()) ?? 0;
      int trackB = int.tryParse(b.track.toString()) ?? 0;
      return trackA.compareTo(trackB);
    });

    return albumSongs
        .where((s) => (s.isMusic ?? false) && (s.duration ?? 0) > 10000)
        .map((s) => Song(
              id: s.uri!,
              title: s.title,
              artist: s.artist ?? "Unknown",
              thumbUrl: "",
              type: 'local',
              localId: s.id,
              albumId: s.albumId,
              duration: Duration(milliseconds: s.duration ?? 0),
            ))
        .toList();
  }

  Future<Uint8List?> getArtwork(int id, ArtworkType type) async {
    final String cacheKey = '${type.toString()}_$id';
    if (_artworkCache.containsKey(cacheKey)) return _artworkCache[cacheKey];

    final Uint8List? artwork = await _audioQuery.queryArtwork(id, type,
        format: ArtworkFormat.PNG, size: 2048);
    if (artwork != null) _artworkCache[cacheKey] = artwork;
    return artwork;
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    _isSearching = true;
    _searchResults.clear();
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(
          'https://music-three-woad.vercel.app/search/songs?q=${Uri.encodeComponent(query)}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Song> results = [];

        if (data['data'] != null && data['data']['results'] is List) {
          for (var item in (data['data']['results'] as List)) {
            try {
              // --- Defensive URL Parsing ---
              String? downloadUrl;
              if (item['downloadUrl'] is List && (item['downloadUrl'] as List).isNotEmpty) {
                  final lastUrl = (item['downloadUrl'] as List).last;
                  if (lastUrl is Map && lastUrl.containsKey('link')) {
                    downloadUrl = lastUrl['link'];
                  }
              }
              if (downloadUrl == null) continue; // Skip if no valid download URL

              // --- Defensive Image Parsing ---
              String imageUrl = '';
              if (item['image'] is List && (item['image'] as List).isNotEmpty) {
                  final lastImage = (item['image'] as List).last;
                   if (lastImage is Map && lastImage.containsKey('link')) {
                    imageUrl = lastImage['link'];
                  }
              }

              // --- Defensive Artist Parsing ---
              String artist = 'Unknown Artist';
              if(item['primaryArtists'] is String) {
                artist = item['primaryArtists'];
              } else if (item['primaryArtists'] is List) {
                artist = (item['primaryArtists'] as List).join(', ');
              }

              // --- Defensive Duration Parsing ---
              Duration? duration;
              if (item['duration'] is String) {
                final seconds = int.tryParse(item['duration']);
                if (seconds != null) {
                  duration = Duration(seconds: seconds);
                }
              }

              results.add(Song(
                id: downloadUrl,
                title: item['name'] as String? ?? 'Unknown Title',
                artist: artist,
                thumbUrl: imageUrl,
                type: 'saavn',
                duration: duration,
              ));
            } catch (e) {
              print("Error parsing individual search item: $e");
              // Optional: Log this error, but don't let one bad item stop the whole list.
              continue;
            }
          }
        }
        _searchResults = results;
      } else {
        _errorMessage = "API Error: Failed to get search results.";
      }
    } catch (e) {
      _errorMessage = "Network Error: Failed to connect to service.";
      print("Saavn search error: $e");
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }


  Future<void> play(Song song, {List<Song>? newQueue}) async {
    if (_audioHandler == null) return;

    try {
      _loadingSongId = song.id;
      notifyListeners();

      if (song.type == 'saavn') {
        // For Saavn songs, create a new queue with the selected song and play it.
        final mediaItem = _songToMediaItem(song);
        await _audioHandler!.updateQueue([mediaItem]);
        await _audioHandler!.play();
      } else {
        // For local songs, use the existing queue logic.
        List<Song> queueToPlay =
            newQueue ?? (_isShuffleEnabled ? _shuffledSongs : _localSongs);
        if (newQueue != null) {
          await _updateQueueWithSongs(queueToPlay);
        }

        final index = queueToPlay.indexWhere((s) => s.id == song.id);
        if (index != -1) {
          await _audioHandler!.skipToQueueItem(index);
          await _audioHandler!.play();
        }
      }

      if (!_isPlayerExpanded) {
        _isPlayerExpanded = true;
      }
    } catch (e) {
      print("Error in play method: $e");
      _errorMessage = "Failed to start playback.";
    } finally {
      _loadingSongId = null;
      notifyListeners();
    }
  }

  Future<void> _updateQueueWithSongs(List<Song> songs) async {
    final mediaItems = songs.map((s) => _songToMediaItem(s)).toList();
    await _audioHandler!.updateQueue(mediaItems);
  }

  MediaItem _songToMediaItem(Song s) {
    return MediaItem(
      id: s.id,
      album: s.type == 'saavn' ? "Saavn" : "Local Music",
      title: s.title,
      artist: s.artist,
      artUri: s.type == 'saavn' ? Uri.parse(s.thumbUrl) : null,
      genre: s.type,
      duration: s.duration,
      extras: {'artworkId': s.localId, 'albumId': s.albumId},
    );
  }

  void togglePlayPause() {
    _audioHandler?.playbackState.value.playing == true
        ? _audioHandler!.pause()
        : _audioHandler!.play();
  }

  void next() => _audioHandler?.skipToNext();
  void previous() => _audioHandler?.skipToPrevious();
  void seek(Duration pos) => _audioHandler?.seek(pos);

  void cycleRepeatMode() {
    if (_audioHandler == null) return;
    final nextMode = {
      AudioServiceRepeatMode.none: AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all: AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one: AudioServiceRepeatMode.none,
    }[_repeatMode];

    if (nextMode != null) {
      _repeatMode = nextMode;
      notifyListeners();
      _audioHandler!.setRepeatMode(nextMode);
    }
  }

  void toggleShuffle() {
    if (_audioHandler == null) return;
    _isShuffleEnabled = !_isShuffleEnabled;
    final newMode = _isShuffleEnabled
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;
    _audioHandler!.setShuffleMode(newMode);

    if (_isShuffleEnabled) {
      _shuffledSongs = List.from(_localSongs)..shuffle();
      _updateQueueWithSongs(_shuffledSongs);
    } else {
      _updateQueueWithSongs(_localSongs);
    }

    notifyListeners();
  }

  void togglePlayerView() {
    _isPlayerExpanded = !_isPlayerExpanded;
    notifyListeners();
  }

  void collapsePlayer() {
    if (_isPlayerExpanded) {
      _isPlayerExpanded = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
