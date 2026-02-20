import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

// A compact, persistent player that docks at the bottom of the screen.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
    final audioHandler = context.watch<AudioHandler>();
    final song = musicProvider.currentSong;

    // The mini player should not be visible if no song is loaded or if the full player is visible.
    if (song == null || musicProvider.isPlayerVisible) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      // Tapping the mini player should expand the full player screen.
      onTap: () => musicProvider.showPlayer(),
      // A swipe up gesture should also expand the player.
      onVerticalDragUpdate: (details) {
        if (details.delta.dy < -10) { // Detect a swipe up
          musicProvider.showPlayer();
        }
      },
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A3D), // A dark, complementary color.
          // Add a border to visually separate it from the main content.
          border: Border(
            top: BorderSide(color: Colors.deepPurple.shade700, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              // Use the corrected artwork builder.
              _buildArtwork(song.highQualityImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Use the correct `name` property from the Song model.
                    Text(
                      song.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Use the corrected `artistNames` getter.
                    Text(
                      song.artistNames,
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Play/Pause button.
              StreamBuilder<PlaybackState>(
                stream: audioHandler.playbackState,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data?.playing ?? false;
                  return IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 36,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        audioHandler.pause();
                      } else {
                        audioHandler.play();
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the artwork for the mini player.
  Widget _buildArtwork(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: FadeInImage.memoryNetwork(
        placeholder: kTransparentImage,
        image: imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        imageErrorBuilder: (c, e, s) => Container(
          width: 50,
          height: 50,
          color: Colors.grey.shade800,
          child: const Icon(Icons.music_note, color: Colors.white),
        ),
      ),
    );
  }
}
