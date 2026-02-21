import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/album_details_screen.dart';
import 'package:oxcy/screens/artist_details_screen.dart';
import 'package:oxcy/screens/playlist_details_screen.dart';
import 'package:oxcy/screens/search_screen_delegate.dart';
import 'package:oxcy/services/oxcy_api_service.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Future<Map<String, List<SearchResult>>> _exploreData;

  @override
  void initState() {
    super.initState();
    _exploreData = OxcyApiService.getHomePageData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Music',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: SearchScreenDelegate());
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, List<SearchResult>>>(
        future: _exploreData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No music content available.'));
          }

          return _buildExploreContent(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildExploreContent(Map<String, List<SearchResult>> data) {
    final albums = data['albums'] ?? [];
    final artists = data['artists'] ?? [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (albums.isNotEmpty)
          _buildHorizontalSection<Album>('Top Albums', albums.cast<Album>()),
        if (artists.isNotEmpty)
          _buildHorizontalSection<Artist>('Top Artists', artists.cast<Artist>()),
      ],
    );
  }

  Widget _buildHorizontalSection<T extends SearchResult>(
      String title, List<T> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: item is Artist
                    ? _buildArtistCard(artist: item)
                    : _buildGenericCard(item: item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildArtistCard({required Artist artist}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ArtistDetailsScreen(artistId: artist.id)),
        );
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(artist.highQualityImageUrl),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericCard({required SearchResult item}) {
    String subtitle = '';
    if (item is Album) subtitle = item.artistNames;

    return GestureDetector(
      onTap: () {
        if (item is Album) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AlbumDetailsScreen(albumId: item.id)));
        } else if (item is Playlist) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      PlaylistDetailsScreen(playlistId: item.id)));
        }
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              clipBehavior: Clip.antiAlias,
              child: FadeInImage.memoryNetwork(
                placeholder: kTransparentImage,
                image: item.highQualityImageUrl,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                imageErrorBuilder: (c, e, s) => Container(
                    width: 140, height: 140, color: Colors.grey.shade800),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
