import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/providers/music_data_provider.dart' hide Album;
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

class ArtistDetailsScreen extends StatefulWidget {
  final String artistId;

  const ArtistDetailsScreen({super.key, required this.artistId});

  @override
  State<ArtistDetailsScreen> createState() => _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends State<ArtistDetailsScreen> {
  final String _baseUrl = "https://music-three-woad.vercel.app";
  Future<Map<String, dynamic>>? _artistDetailsFuture;

  @override
  void initState() {
    super.initState();
    _artistDetailsFuture = _fetchArtistDetails();
  }

  Future<Map<String, dynamic>> _fetchArtistDetails() async {
    try {
      final artistResponse = await http.get(Uri.parse('$_baseUrl/artist?id=${widget.artistId}'));
      final songsResponse = await http.get(Uri.parse('$_baseUrl/artist/songs?id=${widget.artistId}'));
      final albumsResponse = await http.get(Uri.parse('$_baseUrl/artist/albums?id=${widget.artistId}'));

      if (artistResponse.statusCode == 200 && songsResponse.statusCode == 200 && albumsResponse.statusCode == 200) {
        final musicData = Provider.of<MusicData>(context, listen: false);
        final artistData = json.decode(artistResponse.body)['data'];
        final songsData = json.decode(songsResponse.body)['data']['results'];
        final albumsData = json.decode(albumsResponse.body)['data']['results'];

        return {
          'details': musicData.buildArtist(artistData),
          'songs': (songsData as List).map((song) => musicData.buildSong(song)).whereType<Song>().toList(),
          'albums': (albumsData as List).map((album) => musicData.buildAlbum(album)).whereType<Album>().toList(),
        };
      } else {
        throw Exception('Failed to load artist details');
      }
    } catch (e) {
      print("Artist details fetch error: $e");
      throw Exception('A network error occurred.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _artistDetailsFuture,
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

          final Artist details = snapshot.data!['details'];
          final List<Song> songs = snapshot.data!['songs'];
          final List<Album> albums = snapshot.data!['albums'];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                backgroundColor: Colors.transparent,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(details.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  _buildSectionHeader('Top Songs'),
                  ...songs.map((song) => _buildSongItem(song)).toList(),
                   _buildSectionHeader('Albums'),
                   _buildAlbumHorizontalList(albums),
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

  Widget _buildAlbumHorizontalList(List<Album> albums) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: _buildGenericCard(
              title: album.title,
              subtitle: album.subtitle,
              imageUrl: album.imageUrl,
              onTap: () { /* TODO: Navigate to album details */ },
            ),
          );
        },
      ),
    );
  }

    Widget _buildGenericCard({required String title, String? subtitle, required String imageUrl, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              clipBehavior: Clip.antiAlias,
              child: FadeInImage.memoryNetwork(
                placeholder: kTransparentImage,
                image: imageUrl,
                width: 140, height: 140, fit: BoxFit.cover,
                imageErrorBuilder: (c,e,s) => Container(width: 140, height: 140, color: Colors.grey.shade800),
              ),
            ),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (subtitle != null)
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
