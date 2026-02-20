
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

// The main, full-screen player UI.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        // The AnimatedPositioned slides the entire screen up from the bottom.
        // Its visibility is controlled by the isPlayerVisible flag in the provider.
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          // If no song is loaded, hide the player off-screen.
          bottom: musicProvider.currentSong != null && musicProvider.isPlayerVisible ? 0 : -size.height,
          left: 0,
          right: 0,
          child: SizedBox(
            height: size.height,
            // The AnimatedSwitcher will handle the transition between the mini-player and the full player.
            // However, this version only shows the full player, so it is not strictly necessary here but is kept for future enhancements.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _buildExpandedPlayer(context, musicProvider, musicProvider.currentSong!),
            ),
          ),
        );
      },
    );
  }

  // Builds the main expanded player UI.
  Widget _buildExpandedPlayer(BuildContext context, MusicProvider musicProvider, Song song) {
    return GestureDetector(
      // Allow the user to swipe down to hide the player.
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 200) {
          musicProvider.hidePlayer();
        }
      },
      child: ClipRRect(
        child: BackdropFilter(
          // Apply a heavy blur to the background for a frosted-glass effect.
          filter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
          child: Container(
            decoration: BoxDecoration(
              // A subtle gradient provides a premium feel.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.deepPurple.shade700.withOpacity(0.8),
                  const Color(0xFF0F0C29).withOpacity(0.9),
                ],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.expand_more, color: Colors.white),
                  onPressed: () => musicProvider.hidePlayer(),
                ),
                title: const Text('Now Playing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                centerTitle: true,
              ),
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                // Animate the content entrance for a more engaging experience.
                child: AnimationLimiter(
                  child: Column(
                    children: AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 375),
                      childAnimationBuilder: (widget) => SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(child: widget),
                      ),
                      children: [
                        const Spacer(),
                        _buildArtwork(song, isExpanded: true),
                        const SizedBox(height: 40),
                        Text(song.name, // Use name from the Song model.
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(song.artistNames, // Use the new artistNames getter.
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                            textAlign: TextAlign.center),
                        const Spacer(flex: 2),
                        _buildProgressBar(context, musicProvider),
                        _buildControls(context, musicProvider),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Builds the album artwork.
  Widget _buildArtwork(Song song, {required bool isExpanded}) {
    final size = isExpanded ? 280.0 : 50.0;
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isExpanded ? 20 : 8)),
      clipBehavior: Clip.antiAlias,
      child: FadeInImage.memoryNetwork(
        placeholder: kTransparentImage, // Use a transparent placeholder.
        image: song.highQualityImageUrl, // Use the high-quality image URL.
        height: size,
        width: size,
        fit: BoxFit.cover,
        imageErrorBuilder: (ctx, err, stack) => _placeholder(size),
      ),
    );
  }

  Widget _placeholder(double size) => Container(
      height: size, width: size, color: Colors.grey.shade800, child: const Icon(Icons.music_note, color: Colors.white));

  // Builds the interactive progress bar.
  Widget _buildProgressBar(BuildContext context, MusicProvider musicProvider) {
    return StreamBuilder<Duration>(
      stream: musicProvider.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = musicProvider.duration;
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                min: 0.0,
                max: duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  musicProvider.seek(Duration(milliseconds: value.toInt()));
                },
                activeColor: Colors.white,
                inactiveColor: Colors.white.withOpacity(0.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white70)),
                  Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Builds the playback control buttons.
  Widget _buildControls(BuildContext context, MusicProvider musicProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
              icon: Icon(Icons.shuffle, color: musicProvider.isShuffleEnabled ? Colors.deepPurple.shade300 : Colors.white70),
              onPressed: () => musicProvider.toggleShuffle()),
          IconButton(
              icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white),
              onPressed: () => musicProvider.playPrevious()),
          // The main play/pause button.
          IconButton(
            icon: Icon(musicProvider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 70, color: Colors.white),
            onPressed: () => musicProvider.isPlaying ? musicProvider.pause() : musicProvider.resume(),
          ),
          IconButton(
              icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
              onPressed: () => musicProvider.playNext()),
          IconButton(
              icon: Icon(_repeatIcon(musicProvider.repeatMode),
                  color: musicProvider.repeatMode != LoopMode.off ? Colors.deepPurple.shade300 : Colors.white70),
              onPressed: () => musicProvider.cycleRepeatMode()),
        ],
      ),
    );
  }

  // Helper to determine the correct repeat icon.
  IconData _repeatIcon(LoopMode loopMode) {
    if (loopMode == LoopMode.one) return Icons.repeat_one;
    return Icons.repeat;
  }

  // Helper to format duration into a readable string (MM:SS).
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
