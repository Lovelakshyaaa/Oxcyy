import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';

class AlbumSongsScreen extends StatelessWidget {
  final AlbumModel album;

  const AlbumSongsScreen({Key? key, required this.album}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final songsInAlbum = musicProvider.getLocalSongsByAlbum(album.id);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF24243e),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                album.album,
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              background: QueryArtworkWidget(
                id: album.id,
                type: ArtworkType.ALBUM,
                artworkQuality: FilterQuality.high,
                artworkFit: BoxFit.cover,
                nullArtworkWidget: Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.album, color: Colors.white, size: 150),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = songsInAlbum[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: QueryArtworkWidget(
                      id: song.localId!,
                      type: ArtworkType.AUDIO,
                      artworkWidth: 50,
                      artworkHeight: 50,
                      nullArtworkWidget: Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey.withOpacity(0.2),
                        child: const Icon(Icons.music_note, color: Colors.white70),
                      ),
                    ),
                  ),
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                  onTap: () {
                    // When a song is tapped, play it with the context of the current album's song list.
                    musicProvider.play(song, newQueue: songsInAlbum);
                  },
                );
              },
              childCount: songsInAlbum.length,
            ),
          ),
        ],
      ),
    );
  }
}
