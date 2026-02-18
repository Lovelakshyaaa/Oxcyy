import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/album_songs_screen.dart';
import 'package:oxcy/utils/shared_axis_page_route.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class LocalMusicScreen extends StatelessWidget {
  const LocalMusicScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text("My Albums",
                      style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                if (provider.isFetchingLocal)
                  const Expanded(
                      child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)))
                else if (provider.localAlbums.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_off,
                              size: 80, color: Colors.white24),
                          const SizedBox(height: 10),
                          const Text("No local albums found",
                              style: TextStyle(color: Colors.white54)),
                          TextButton(
                            onPressed: () => provider.fetchLocalMusic(),
                            child: const Text("Refresh",
                                style: TextStyle(color: Colors.purpleAccent)),
                          )
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: AnimationLimiter(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0)
                            .copyWith(bottom: 100.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: provider.localAlbums.length,
                        itemBuilder: (context, index) {
                          final album = provider.localAlbums[index];
                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            columnCount: 2,
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      SharedAxisPageRoute(
                                          page: AlbumSongsScreen(album: album)),
                                    );
                                  },
                                  child: GlassmorphicContainer(
                                    width: double.infinity,
                                    height: double.infinity,
                                    borderRadius: 20,
                                    blur: 15,
                                    border: 1,
                                    linearGradient: LinearGradient(colors: [
                                      Colors.white.withOpacity(0.1),
                                      Colors.white.withOpacity(0.05)
                                    ]),
                                    borderGradient: LinearGradient(colors: [
                                      Colors.white.withOpacity(0.2),
                                      Colors.white.withOpacity(0.1)
                                    ]),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(20.0)),
                                            child: FutureBuilder<Uint8List?>(
                                              future: provider.getArtwork(
                                                  album.id, ArtworkType.ALBUM),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData &&
                                                    snapshot.data != null) {
                                                  return Image.memory(
                                                    snapshot.data!,
                                                    fit: BoxFit.cover,
                                                    gaplessPlayback: true,
                                                    filterQuality:
                                                        FilterQuality.high,
                                                  );
                                                }
                                                return Container(
                                                  color: Colors.grey
                                                      .withOpacity(0.1),
                                                  child: const Center(
                                                    child: Icon(Icons.album,
                                                        color: Colors.white54,
                                                        size: 50),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                album.album,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                album.artist ??
                                                    "Unknown Artist",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white54,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
