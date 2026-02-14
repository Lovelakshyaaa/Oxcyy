import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:oxcy/services/audio_handler.dart';

// Represents a single song, abstracting over local and YouTube sources.
class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbUrl;
  final String type;
  final int? localId;
  final int? albumId; // Keep track of album ID
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
  final YoutubeExplode _yt = YoutubeExplode();

  AudioHandler? _audioHandler;
  AudioHandler? get audioHandler => _audioHandler;

  List<Song> _searchResults = [];
  List<Song> get searchResults => _searchResults;

  List<AlbumModel> _localAlbums = [];
  List<AlbumModel> get localAlbums => _localAlbums;

  List<Song> _localSongs = [];
  List<Song> get localSongs => _localSongs;
  
  List<Song> _shuffledSongs = [];

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  bool _isFetchingLocal = true;
  bool get isFetchingLocal => _isFetchingLocal;
  
  bool _isPlayerExpanded = false;
  bool get isPlayerExpanded => _isPlayerExpanded;

  bool _isShuffleEnabled = false;
  bool get isShuffleEnabled => _isShuffleEnabled;

  MusicProvider() {
    _init();
  }

  Future<void> _init() async {
    _audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ryan.my_app.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ),
    );
    fetchLocalMusic();
  }

  Future<void> fetchLocalMusic() async {
    _isFetchingLocal = true;
    notifyListeners();

    try {
      if (await Permission.audio.request().isGranted || await Permission.storage.request().isGranted) {
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
          await _updateQueueWithSongs(_isShuffleEnabled ? _shuffledSongs : _localSongs);
        }
      }
    } catch (e) {
      print("Error fetching local music: $e");
    } finally {
      _isFetchingLocal = false;
      notifyListeners();
    }
  }

  // FIX: Correctly query songs for a specific album
  Future<List<Song>> getLocalSongsByAlbum(int albumId) async {
    List<SongModel> albumSongs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      albumId,
      sortType: SongSortType.TRACK,
      orderType: OrderType.ASC_OR_SMALLER,
    );

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

  // FIX: Get high-resolution artwork for the player
  Future<ArtworkModel?> getArtwork(int id, ArtworkType type) async {
    final artwork = await _audioQuery.queryArtwork(id, type, size: 1000);
    return artwork;
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    _isSearching = true;
    _searchResults.clear();
    notifyListeners();

    try {
      var searchResults = await _yt.search.search(query);
      _searchResults = searchResults.map((v) {
        return Song(
          id: v.id.value,
          title: v.title,
          artist: v.author,
          thumbUrl: v.thumbnails.highResUrl,
          type: 'youtube',
          duration: v.duration,
        );
      }).toList();
    } catch (e) {
      print("Error searching YouTube: $e");
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> play(Song song, {List<Song>? newQueue}) async {
    if (_audioHandler == null) return;

    try {
      String? streamUrl;
      if (song.type == 'youtube') {
        var manifest = await _yt.videos.streamsClient.getManifest(song.id);
        streamUrl = manifest.audioOnly.withHighestBitrate().url.toString();
      }

      final mediaItem = _songToMediaItem(song).copyWith(extras: {
        ...song.type == 'youtube' ? {'url': streamUrl} : {},
        'artworkId': song.localId,
      });

      List<Song> queueToPlay;

      if (newQueue != null) {
        queueToPlay = newQueue;
        await _updateQueueWithSongs(queueToPlay);
      } else if (song.type == 'local') {
        queueToPlay = _isShuffleEnabled ? _shuffledSongs : _localSongs;
      } else {
        await _audioHandler!.addQueueItem(mediaItem);
        await _audioHandler!.skipToQueueItem(_audioHandler!.queue.value.length - 1);
        _audioHandler!.play();
        if (!_isPlayerExpanded) {
          _isPlayerExpanded = true;
          notifyListeners();
        }
        return;
      }
      
      final index = queueToPlay.indexWhere((s) => s.id == song.id);
      if (index != -1) {
        await _audioHandler!.skipToQueueItem(index);
      } else {
        await _audioHandler!.addQueueItem(mediaItem);
        await _audioHandler!.skipToQueueItem(_audioHandler!.queue.value.length - 1);
      }
      
      _audioHandler!.play();

      if (!_isPlayerExpanded) {
        _isPlayerExpanded = true;
        notifyListeners();
      }
    } catch (e) {
      print("Error playing song: $e");
    }
  }
  
  Future<void> _updateQueueWithSongs(List<Song> songs) async {
    final mediaItems = songs.map((s) => _songToMediaItem(s)).toList();
    await _audioHandler!.updateQueue(mediaItems);
  }

  MediaItem _songToMediaItem(Song s) {
    return MediaItem(
      id: s.id,
      album: s.type == 'local' ? "Local Music" : "YouTube",
      title: s.title,
      artist: s.artist,
      artUri: s.type == 'youtube' ? Uri.parse(s.thumbUrl) : null,
      genre: s.type,
      duration: s.duration,
      extras: {'artworkId': s.localId, 'albumId': s.albumId},
    );
  }

  void togglePlayPause() {
    if (_audioHandler?.playbackState.value.playing == true) {
      _audioHandler!.pause();
    } else {
      _audioHandler!.play();
    }
  }

  void next() => _audioHandler?.skipToNext();
  void previous() => _audioHandler?.skipToPrevious();
  void seek(Duration pos) => _audioHandler?.seek(pos);
  
  void cycleRepeatMode() {
    if (_audioHandler == null) return;
    final currentMode = _audioHandler!.playbackState.value.repeatMode;
    final nextMode = {
      AudioServiceRepeatMode.none: AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all: AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one: AudioServiceRepeatMode.none,
    }[currentMode];
    _audioHandler!.setRepeatMode(nextMode!);
  }

  void toggleShuffle() {
    if (_audioHandler == null) return;
    _isShuffleEnabled = !_isShuffleEnabled;
    final newMode = _isShuffleEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
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
    _yt.close();
    super.dispose();
  }
}
