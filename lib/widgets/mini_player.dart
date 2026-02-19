import 'package:flutter/material.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:on_audio_query/on_audio_query.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
    final song = musicProvider.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => musicProvider.togglePlayerView(),
      child: Container(
        height: 85,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A3D),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          border: Border(
            top: BorderSide(color: Colors.deepPurple.shade700, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              _buildArtwork(context, song),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      song.artist,
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  musicProvider.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 36,
                ),
                onPressed: () {
                  if (musicProvider.isPlaying) {
                    musicProvider.pause();
                  } else {
                    musicProvider.resume();
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context, dynamic song) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: song.thumbUrl != null && song.thumbUrl.isNotEmpty
          ? Image.network(
              song.thumbUrl,
              height: 50,
              width: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  const Icon(Icons.music_note, size: 50),
            )
          : FutureBuilder<Uint8List?>(
              future: Provider.of<MusicProvider>(context, listen: false)
                  .getArtwork(int.parse(song.id), ArtworkType.AUDIO),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    height: 50,
                    width: 50,
                    fit: BoxFit.cover,
                  );
                }
                return Container(
                  height: 50,
                  width: 50,
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.music_note, size: 30),
                );
              },
            ),
    );
  }
}
