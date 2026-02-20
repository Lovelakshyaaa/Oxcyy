
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          bottom: musicProvider.currentSong != null && musicProvider.isPlayerVisible ? 0 : -size.height,
          left: 0,
          right: 0,
          child: SizedBox(
            height: size.height,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: musicProvider.currentSong != null
                  ? _buildExpandedPlayer(context, musicProvider, musicProvider.currentSong!)
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedPlayer(BuildContext context, MusicProvider musicProvider, Song song) {
    final audioHandler = Provider.of<AudioHandler>(context, listen: false);
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 200) {
          musicProvider.hidePlayer();
        }
      },
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
          child: Container(
            decoration: BoxDecoration(
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
                        Text(song.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(song.artistNames,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                            textAlign: TextAlign.center),
                        const Spacer(flex: 2),
                        _buildProgressBar(context, audioHandler),
                        _buildControls(context, audioHandler),
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

  Widget _buildArtwork(Song song, {required bool isExpanded}) {
    final size = isExpanded ? 280.0 : 50.0;
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isExpanded ? 20 : 8)),
      clipBehavior: Clip.antiAlias,
      child: FadeInImage.memoryNetwork(
        placeholder: kTransparentImage,
        image: song.highQualityImageUrl,
        height: size,
        width: size,
        fit: BoxFit.cover,
        imageErrorBuilder: (ctx, err, stack) => _placeholder(size),
      ),
    );
  }

  Widget _placeholder(double size) => Container(
      height: size, width: size, color: Colors.grey.shade800, child: const Icon(Icons.music_note, color: Colors.white));

  Widget _buildProgressBar(BuildContext context, AudioHandler audioHandler) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final position = playbackState?.updatePosition ?? Duration.zero;
        final duration = audioHandler.mediaItem.value?.duration ?? Duration.zero;
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
                  audioHandler.seek(Duration(milliseconds: value.toInt()));
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

  Widget _buildControls(BuildContext context, AudioHandler audioHandler) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final isPlaying = playbackState?.playing ?? false;
        final shuffleMode = playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;
        final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                  icon: Icon(Icons.shuffle, color: shuffleMode != AudioServiceShuffleMode.none ? Colors.deepPurple.shade300 : Colors.white70),
                  onPressed: () => audioHandler.setShuffleMode(shuffleMode == AudioServiceShuffleMode.none
                      ? AudioServiceShuffleMode.all
                      : AudioServiceShuffleMode.none)),
              IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white),
                  onPressed: audioHandler.skipToPrevious),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 70, color: Colors.white),
                onPressed: isPlaying ? audioHandler.pause : audioHandler.play,
              ),
              IconButton(
                  icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
                  onPressed: audioHandler.skipToNext),
              IconButton(
                  icon: Icon(_repeatIcon(repeatMode), color: repeatMode != AudioServiceRepeatMode.none ? Colors.deepPurple.shade300 : Colors.white70),
                  onPressed: () {
                    final nextMode = {
                      AudioServiceRepeatMode.none: AudioServiceRepeatMode.all,
                      AudioServiceRepeatMode.all: AudioServiceRepeatMode.one,
                      AudioServiceRepeatMode.one: AudioServiceRepeatMode.none,
                    }[repeatMode]!;
                    audioHandler.setRepeatMode(nextMode);
                  }),
            ],
          ),
        );
      },
    );
  }

  IconData _repeatIcon(AudioServiceRepeatMode repeatMode) {
    if (repeatMode == AudioServiceRepeatMode.one) return Icons.repeat_one;
    return Icons.repeat;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
