import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_data_provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/artist_details_screen.dart';
import 'package:oxcy/screens/album_details_screen.dart';
import 'package:oxcy/screens/playlist_details_screen.dart';
import 'package:oxcy/screens/search_screen_delegate.dart';
import 'package:transparent_image/transparent_image.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Music', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Use the custom SearchScreenDelegate to handle the search UI.
              showSearch(context: context, delegate: SearchScreenDelegate());
            },
          ),
        ],
      ),
      body: Consumer<MusicData>(
        builder: (context, musicData, child) {
          // Show a loading indicator while fetching initial data.
          if (musicData.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show an error message if something went wrong.
          if (musicData.errorMessage != null) {
            return Center(child: Text(musicData.errorMessage!));
          }

          // Build the main content of the explore screen.
          return _buildExploreContent(musicData);
        },
      ),
    );
  }

  // Builds the scrollable list of music sections.
  Widget _buildExploreContent(MusicData musicData) {
    // Use a ListView to display the different modules fetched from the API.
    return ListView(
      padding: const EdgeInsets.only(bottom: 120), // Add padding for the mini-player
      children: [
        if (musicData.modules.containsKey('trending_songs'))
          _buildSongSection('Trending Now', musicData.modules['trending_songs']! as List<Song>),
        if (musicData.modules.containsKey('trending_albums'))
          _buildHorizontalSection<Album>('Trending Albums', musicData.modules['trending_albums']! as List<Album>),
        if (musicData.modules.containsKey('playlists'))
          _buildHorizontalSection<Playlist>('Playlists', musicData.modules['playlists']! as List<Playlist>),
        if (musicData.modules.containsKey('charts'))
          _buildHorizontalSection<Chart>('Charts', musicData.modules['charts']! as List<Chart>),
        if (musicData.modules.containsKey('albums'))
          _buildHorizontalSection<Album>('Top Albums', musicData.modules['albums']! as List<Album>),
        if (musicData.modules.containsKey('artists'))
         _buildHorizontalSection<Artist>('Top Artists', musicData.modules['artists']! as List<Artist>),
      ],
    );
  }

  // Builds a vertically scrolling section for a list of songs.
  Widget _buildSongSection(String title, List<Song> songs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        // Map each song to a ListTile widget.
        ...songs.map((song) => _buildSongItem(song)).toList(),
      ],
    );
  }

  // Generic builder for a horizontally scrolling section.
  Widget _buildHorizontalSection<T extends SearchResult>(String title, List<T> items) {
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
              // Determine the widget type based on the model.
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

  // Builds a standard section header.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  // Builds a list tile for a single song.
  Widget _buildSongItem(Song song) {
    return ListTile(
      leading: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage, // Shows a transparent placeholder.
          image: song.highQualityImageUrl, // Use the new getter for the best image.
          width: 56, height: 56, fit: BoxFit.cover,
          imageErrorBuilder: (c, e, s) => const Icon(Icons.music_note, size: 56),
        ),
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(song.artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        // Play the selected song using the MusicProvider.
        Provider.of<MusicProvider>(context, listen: false).play(song);
      },
    );
  }

  // Builds a circular card for an artist.
  Widget _buildArtistCard({required Artist artist}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ArtistDetailsScreen(artistId: artist.id)),
        );
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(artist.highQualityImageUrl), // Use the new getter.
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

  // Builds a generic rectangular card for albums, playlists, and charts.
  Widget _buildGenericCard({required SearchResult item}) {
    String subtitle = '';
    if (item is Album) subtitle = item.artistNames;

    return GestureDetector(
      onTap: () {
        // Navigate to the correct details screen based on the item type.
        if (item is Album) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AlbumDetailsScreen(albumId: item.id)));
        } else if (item is Playlist || item is Chart) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PlaylistDetailsScreen(playlistId: item.id)));
        }
      },
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
                image: item.highQualityImageUrl, // Use the new getter.
                width: 140, height: 140, fit: BoxFit.cover,
                imageErrorBuilder: (c, e, s) => Container(width: 140, height: 140, color: Colors.grey.shade800),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (subtitle.isNotEmpty)
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
