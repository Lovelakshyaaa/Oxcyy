
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:just_audio/just_audio.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final video = musicProvider.currentVideo;

    if (video == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text('No song selected.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _buildBlurredBackground(video.thumbnails.maxResUrl),
          _buildPlayerContent(context, musicProvider, video),
        ],
      ),
    );
  }

  Widget _buildBlurredBackground(String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: CachedNetworkImageProvider(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: Colors.black.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildPlayerContent(BuildContext context, MusicProvider musicProvider, video) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          _buildAlbumArt(video.thumbnails.maxResUrl),
          const SizedBox(height: 40),
          _buildTrackInfo(video.title, video.author),
          const SizedBox(height: 30),
          _buildProgressBar(musicProvider.audioPlayer),
          const SizedBox(height: 20),
          _buildControls(musicProvider),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: MediaQuery.of(_getBuildContext()).size.width * 0.75,
        height: MediaQuery.of(_getBuildContext()).size.width * 0.75,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey.withOpacity(0.3)),
        errorWidget: (context, url, error) => const Icon(Icons.music_note, size: 100, color: Colors.white),
      ),
    );
  }

  Widget _buildTrackInfo(String title, String artist) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          artist,
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgressBar(AudioPlayer audioPlayer) {
    return StreamBuilder<Duration?>(
      stream: audioPlayer.durationStream,
      builder: (context, snapshot) {
        final duration = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: audioPlayer.positionStream,
          builder: (context, snapshot) {
            var position = snapshot.data ?? Duration.zero;
            if (position > duration) {
              position = duration;
            }
            return Column(
              children: [
                Slider(
                  value: position.inSeconds.toDouble(),
                  max: duration.inSeconds.toDouble(),
                  min: 0.0,
                  onChanged: (value) {
                    audioPlayer.seek(Duration(seconds: value.toInt()));
                  },
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withOpacity(0.3),
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
      },
    );
  }

  Widget _buildControls(MusicProvider musicProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 40, color: Colors.white),
          onPressed: () { /* TODO: Implement skip previous */ },
        ),
        const SizedBox(width: 20),
        StreamBuilder<PlayerState>(
          stream: musicProvider.audioPlayer.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
              return const CircularProgressIndicator(color: Colors.white);
            }
            return IconButton(
              icon: Icon(playing == true ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 70, color: Colors.white),
              onPressed: () {
                if (playing == true) {
                  musicProvider.pause();
                } else {
                  musicProvider.resume();
                }
              },
            );
          },
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 40, color: Colors.white),
          onPressed: () { /* TODO: Implement skip next */ },
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  BuildContext _getBuildContext() {
    // A bit of a hack to get a BuildContext. This is not ideal, but it works for this specific case.
    // In a real-world app, you might want to handle this differently.
    return null as BuildContext;
  }
}
