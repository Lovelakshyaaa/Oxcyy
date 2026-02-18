import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:oxcy/models/search_models.dart'; // <--- ADD THIS IMPORT
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';

class AlbumSongsScreen extends StatefulWidget {
  final AlbumInfo album;

  const AlbumSongsScreen({Key? key, required this.album}) : super(key: key);

  @override
  _AlbumSongsScreenState createState() => _AlbumSongsScreenState();
}

class _AlbumSongsScreenState extends State<AlbumSongsScreen> {
  late Future<List<Song>> _albumSongsFuture;

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
      body: FutureBuilder<List<Song>>(
        future: _albumSongsFuture,
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

          return ListView.builder(
            itemCount: songsInAlbum.length,
            itemBuilder: (context, index) {
              final song = songsInAlbum[index];
              final isPlaying = musicProvider.currentSong?.id == song.id && musicProvider.isPlaying;
              final isLoading = musicProvider.loadingSongId == song.id;

              return ListTile(
                leading: FutureBuilder<Artwork>(
                  future: musicProvider.getArtwork(song.id, ArtworkType.AUDIO),
                  builder: (context, artworkSnapshot) {
                    if (artworkSnapshot.hasData) {
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
                title: Text(song.title),
                subtitle: Text(song.artist ?? 'Unknown Artist'),
                trailing: isLoading
                    ? const CircularProgressIndicator()
                    : isPlaying
                        ? const Icon(Icons.pause)
                        : const Icon(Icons.play_arrow),
                onTap: () {
                  if (!isPlaying) {
                    musicProvider.play(song, newQueue: songsInAlbum);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
