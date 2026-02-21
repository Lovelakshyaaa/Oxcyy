import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:oxcy/models/search_models.dart'; 
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';

class AlbumSongsScreen extends StatefulWidget {
  final AlbumModel album; // Corrected Type: Use AlbumModel from on_audio_query

  const AlbumSongsScreen({Key? key, required this.album}) : super(key: key);

  @override
  _AlbumSongsScreenState createState() => _AlbumSongsScreenState();
}

class _AlbumSongsScreenState extends State<AlbumSongsScreen> {
  late Future<List<SongModel>> _albumSongsFuture; // Corrected Type: Use SongModel

  @override
  void initState() {
    super.initState();
    _albumSongsFuture = Provider.of<MusicProvider>(context, listen: false)
        .getLocalSongsByAlbum(widget.album.id);
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album.album),
      ),
      body: FutureBuilder<List<SongModel>>(
        future: _albumSongsFuture, // Corrected future
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No songs found in this album.'));
          }

          final songsInAlbum = snapshot.data!;

          return StreamBuilder<PlaybackState>(
            stream: musicProvider.playbackState, // Listen to the stream
            builder: (context, playbackSnapshot) {
              final playbackState = playbackSnapshot.data;
              final isPlaying = playbackState?.playing ?? false;
              final currentMediaId = playbackState?.currentMediaItem?.id;

              return ListView.builder(
                itemCount: songsInAlbum.length,
                itemBuilder: (context, index) {
                  final song = songsInAlbum[index];
                  final isThisSongPlaying = isPlaying && currentMediaId == song.id.toString();
                  final isLoading = musicProvider.loadingSongId == song.id.toString();

                  return ListTile(
                    leading: FutureBuilder<Uint8List?>(
                      future: musicProvider.getArtwork(song.id, ArtworkType.AUDIO),
                      builder: (context, artworkSnapshot) {
                        if (artworkSnapshot.hasData && artworkSnapshot.data != null) {
                          return CircleAvatar(
                            backgroundImage: MemoryImage(artworkSnapshot.data!),
                          );
                        } else {
                          return const CircleAvatar(
                            child: Icon(Icons.music_note),
                          );
                        }
                      },
                    ),
                    title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(song.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.0))
                        : IconButton(
                            icon: Icon(isThisSongPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                            iconSize: 32.0,
                            onPressed: () {
                              if (isThisSongPlaying) {
                                musicProvider.pause();
                              } else {
                                // Set the whole album as the playlist and start from the tapped song
                                musicProvider.setPlaylist(songsInAlbum, initialIndex: index);
                              }
                            },
                          ),
                    onTap: () {
                        if (isThisSongPlaying) {
                          musicProvider.pause();
                        } else {
                          musicProvider.setPlaylist(songsInAlbum, initialIndex: index);
                        }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
