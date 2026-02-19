import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/models/search_models.dart';
import 'dart:typed_data';
import 'package:on_audio_query/on_audio_query.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final song = musicProvider.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.deepPurple.shade800,
                Colors.deepPurple.shade900,
              ],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: musicProvider.isPlayerExpanded ? IconButton(
                icon: const Icon(Icons.expand_more),
                onPressed: () => musicProvider.collapsePlayer(),
              ) : null,
              title: musicProvider.isPlayerExpanded ? Text(song.title) : null,
              centerTitle: true,
            ),
            body: _buildPlayerBody(context, musicProvider, song),
          ),
        );
      },
    );
  }

  Widget _buildPlayerBody(BuildContext context, MusicProvider musicProvider, Song song) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: musicProvider.isPlayerExpanded
          ? _buildExpandedPlayer(context, musicProvider, song)
          : _buildCollapsedPlayer(context, musicProvider, song),
    );
  }

  Widget _buildCollapsedPlayer(BuildContext context, MusicProvider musicProvider, Song song) {
    return GestureDetector(
      onTap: () => musicProvider.togglePlayerView(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.black.withOpacity(0.3),
        child: Row(
          children: [
            _buildArtwork(song, isExpanded: false),
            const SizedBox(width: 10),
            Expanded(child: Text(song.title, overflow: TextOverflow.ellipsis)),
            IconButton(icon: const Icon(Icons.skip_previous), onPressed: () {}), // Add logic
            IconButton(
              icon: Icon(musicProvider.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => musicProvider.isPlaying ? musicProvider.pause() : musicProvider.resume(),
            ),
            IconButton(icon: const Icon(Icons.skip_next), onPressed: () {}), // Add logic
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedPlayer(BuildContext context, MusicProvider musicProvider, Song song) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          _buildArtwork(song, isExpanded: true),
          const SizedBox(height: 40),
          Text(song.title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center), // Corrected: headline5 -> headlineSmall
          const SizedBox(height: 10),
          Text(song.artist, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center), // Corrected: subtitle1 -> titleMedium
          const Spacer(),
          _buildProgressBar(context, musicProvider),
          _buildControls(context, musicProvider),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildArtwork(Song song, {required bool isExpanded}) {
    final size = isExpanded ? 250.0 : 50.0;
    return ClipRRect(
        borderRadius: BorderRadius.circular(isExpanded ? 16.0 : 8.0),
        child: song.thumbUrl.isNotEmpty
        ? Image.network(
            song.thumbUrl,
            height: size,
            width: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _placeholder(size),
          )
        : FutureBuilder<Uint8List?>(
            future: Provider.of<MusicProvider>(_scaffoldKey.currentContext!, listen: false).getArtwork(int.parse(song.id), ArtworkType.AUDIO),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                return Image.memory(snapshot.data!, height: size, width: size, fit: BoxFit.cover);
              } else {
                return _placeholder(size);
              }
            },
          )
    );
  }

  Widget _placeholder(double size) => Container(height: size, width: size, color: Colors.grey.shade800, child: const Icon(Icons.music_note, color: Colors.white, size: 50));


  Widget _buildProgressBar(BuildContext context, MusicProvider musicProvider) {
    return Column(
      children: [
        Slider(
          value: musicProvider.position.inSeconds.toDouble(),
          min: 0.0,
          max: musicProvider.duration.inSeconds.toDouble() + 1.0,
          onChanged: (value) {
            musicProvider.seek(Duration(seconds: value.toInt()));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(musicProvider.position)),
              Text(_formatDuration(musicProvider.duration)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, MusicProvider musicProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(icon: Icon(Icons.shuffle, color: musicProvider.isShuffleEnabled ? Theme.of(context).colorScheme.primary : Colors.white), onPressed: () => musicProvider.toggleShuffle()),
        IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: () {}), // Add logic
        IconButton(
          icon: Icon(musicProvider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 70),
          onPressed: () => musicProvider.isPlaying ? musicProvider.pause() : musicProvider.resume(),
        ),
        IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: () {}), // Add logic
        IconButton(icon: Icon(_repeatIcon(musicProvider.repeatMode), color: musicProvider.repeatMode != LoopMode.off ? Theme.of(context).colorScheme.primary : Colors.white), onPressed: () => musicProvider.cycleRepeatMode()),
      ],
    );
  }

  IconData _repeatIcon(LoopMode loopMode) {
    if (loopMode == LoopMode.one) return Icons.repeat_one;
    if (loopMode == LoopMode.all) return Icons.repeat;
    return Icons.repeat;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
