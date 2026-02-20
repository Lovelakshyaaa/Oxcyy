import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/album_details_screen.dart';
import 'package:oxcy/services/oxcy_api_service.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

class ArtistDetailsScreen extends StatefulWidget {
  final String artistId;

  const ArtistDetailsScreen({super.key, required this.artistId});

  @override
  State<ArtistDetailsScreen> createState() => _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends State<ArtistDetailsScreen> {
  Future<Map<String, dynamic>>? _artistDetailsFuture;

  @override
  void initState() {
    super.initState();
    _artistDetailsFuture = _fetchArtistDetails();
  }

  Future<Map<String, dynamic>> _fetchArtistDetails() async {
    try {
      final artistData = await OxcyApiService.getArtistById(widget.artistId);

      if (artistData == null) {
        throw Exception('No data found for this artist.');
      }

      final songs = (artistData['topSongs'] as List)
          .map((songData) => Song.fromJson(songData))
          .toList();

      final albums = (artistData['topAlbums'] as List)
          .map((albumData) => Album.fromJson(albumData))
          .toList();

      return {
        'details': Artist.fromJson(artistData),
        'songs': songs,
        'albums': albums,
      };
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
                    image: details.highQualityImageUrl,
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
          image: song.highQualityImageUrl,
          width: 56, height: 56, fit: BoxFit.cover,
          imageErrorBuilder: (c,e,s) => const Icon(Icons.music_note, size: 56),
        ),
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(song.artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              title: album.name,
              imageUrl: album.highQualityImageUrl,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumDetailsScreen(albumId: album.id),
                  ),
                );
              },
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
