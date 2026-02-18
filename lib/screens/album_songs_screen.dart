import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class AlbumSongsScreen extends StatefulWidget {
  final AlbumModel album;

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
                widget.album.album,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              background: FutureBuilder<Uint8List?>(
                future: musicProvider.getArtwork(
                    widget.album.id, ArtworkType.ALBUM),
                builder: (context, snapshot) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: snapshot.hasData && snapshot.data != null
                        ? Image.memory(
                            snapshot.data!,
                            key: const ValueKey<int>(1),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.high,
                          )
                        : Container(
                            key: const ValueKey<int>(2),
                            color: Colors.grey[900],
                            child: const Icon(Icons.album,
                                color: Colors.white, size: 150),
                          ),
                  );
                },
              ),
            ),
          ),
          FutureBuilder<List<Song>>(
            future: _albumSongsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text('No songs found in this album.')),
                );
              }

              final songsInAlbum = snapshot.data!;

              return AnimationLimiter(
                child: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songsInAlbum[index];
                      final isLoading = musicProvider.loadingSongId == song.id;
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: FutureBuilder<Uint8List?>(
                                  future: musicProvider.getArtwork(
                                      song.localId!, ArtworkType.AUDIO),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData &&
                                        snapshot.data != null) {
                                      return Image.memory(
                                        snapshot.data!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                        filterQuality: FilterQuality.high,
                                      );
                                    }
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey.withOpacity(0.2),
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white70),
                                    );
                                  },
                                ),
                              ),
                              title: Text(song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(song.artist ?? "Unknown Artist",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 13)),
                              trailing: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.purpleAccent)
                                  : null,
                              onTap: isLoading
                                  ? null
                                  : () {
                                      musicProvider.play(song,
                                          newQueue: songsInAlbum);
                                      Navigator.pop(context);
                                    },
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: songsInAlbum.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
