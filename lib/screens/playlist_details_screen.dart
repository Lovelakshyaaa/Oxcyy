import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/services/oxcy_api_service.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailsScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  Future<Map<String, dynamic>>? _playlistDetailsFuture;

  @override
  void initState() {
    super.initState();
    _playlistDetailsFuture = _fetchPlaylistDetails();
  }

  Future<Map<String, dynamic>> _fetchPlaylistDetails() async {
    try {
      final playlistData = await OxcyApiService.getPlaylistById(widget.playlistId);

      if (playlistData == null) {
        throw Exception('No data found for this playlist.');
      }

      final songs = (playlistData['songs'] as List)
          .map((songData) => Song.fromJson(songData))
          .toList();

      return {
        'details': Playlist.fromJson(playlistData),
        'songs': songs,
      };
    } catch (e) {
      print("Playlist details fetch error: $e");
      throw Exception('A network error occurred.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _playlistDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Error: ${snapshot.error ?? "Could not load details."}'));
          }

          final Playlist? details = snapshot.data!['details'];
          final List<Song> songs = snapshot.data!['songs'];

          if (details == null) {
            return const Center(child: Text('Playlist details could not be loaded.'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                backgroundColor: Colors.transparent,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(details.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  background: FadeInImage.memoryNetwork(
                    placeholder: kTransparentImage,
                    image: details.highQualityImageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    imageErrorBuilder: (c, e, s) => Container(color: Colors.grey[800]),
                  ),
                ),
              ),
              if (songs.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("No songs found in this playlist.")),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    ...songs.map((song) => _buildSongItem(song)).toList(),
                    const SizedBox(height: 120), // Padding for player
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSongItem(Song song) {
    return ListTile(
      leading: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: song.highQualityImageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          imageErrorBuilder: (c, e, s) => const Icon(Icons.music_note, size: 56),
        ),
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(song.artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Provider.of<MusicProvider>(context, listen: false).play(song),
    );
  }
}
