import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/providers/music_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

class AlbumDetailsScreen extends StatefulWidget {
  final String albumId;

  const AlbumDetailsScreen({super.key, required this.albumId});

  @override
  State<AlbumDetailsScreen> createState() => _AlbumDetailsScreenState();
}

class _AlbumDetailsScreenState extends State<AlbumDetailsScreen> {
  final String _baseUrl = "https://music-three-woad.vercel.app";
  Future<Map<String, dynamic>>? _albumDetailsFuture;

  @override
  void initState() {
    super.initState();
    _albumDetailsFuture = _fetchAlbumDetails();
  }

  Future<Map<String, dynamic>> _fetchAlbumDetails() async {
    try {
      final albumResponse = await http.get(Uri.parse('$_baseUrl/album?id=${widget.albumId}'));

      if (albumResponse.statusCode == 200) {
        final musicData = Provider.of<MusicData>(context, listen: false);
        final albumData = json.decode(albumResponse.body)['data'];

        return {
          'details': musicData.buildAlbum(albumData),
          'songs': (albumData['songs'] as List).map((song) => musicData.buildSong(song)).whereType<Song>().toList(),
        };
      } else {
        throw Exception('Failed to load album details');
      }
    } catch (e) {
      print("Album details fetch error: $e");
      throw Exception('A network error occurred.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _albumDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No details found.'));
          }

          final Album details = snapshot.data!['details'];
          final List<Song> songs = snapshot.data!['songs'];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                backgroundColor: Colors.transparent,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(details.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  background: FadeInImage.memoryNetwork(
                    placeholder: kTransparentImage,
                    image: details.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  ...songs.map((song) => _buildSongItem(song)).toList(),
                  const SizedBox(height: 120), // Padding
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
          image: song.thumbUrl,
          width: 56, height: 56, fit: BoxFit.cover,
          imageErrorBuilder: (c,e,s) => const Icon(Icons.music_note, size: 56),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Provider.of<MusicProvider>(context, listen: false).play(song),
    );
  }
}
