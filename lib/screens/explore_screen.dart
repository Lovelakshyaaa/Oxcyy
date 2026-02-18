import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_data_provider.dart' hide Playlist, Chart;
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/artist_details_screen.dart';
import 'package:oxcy/screens/album_details_screen.dart';
import 'package:oxcy/screens/playlist_details_screen.dart';
import 'package:transparent_image/transparent_image.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(BuildContext context) {
    final query = _searchController.text.trim();
    Provider.of<MusicData>(context, listen: false).search(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for music...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          onSubmitted: (_) => _performSearch(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              Provider.of<MusicData>(context, listen: false).clearSearch();
            },
          )
        ],
      ),
      body: Consumer<MusicData>(
        builder: (context, musicData, child) {
          if (musicData.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (musicData.errorMessage != null) {
            return Center(child: Text(musicData.errorMessage!));
          }

          final isSearching = _searchController.text.isNotEmpty;

          return isSearching
              ? _buildSearchResults(musicData)
              : _buildExploreContent(musicData);
        },
      ),
    );
  }

  Widget _buildExploreContent(MusicData musicData) {
    return ListView(
      children: [
        if (musicData.modules.containsKey('trending_songs'))
          _buildSongSection('Trending Now', musicData.modules['trending_songs']! as List<Song>),
        if (musicData.modules.containsKey('trending_albums'))
          _buildAlbumSection('Trending Albums', musicData.modules['trending_albums']! as List<Album>),
        if (musicData.modules.containsKey('playlists'))
          _buildPlaylistSection('Playlists', musicData.modules['playlists']! as List<Playlist>),
        if (musicData.modules.containsKey('charts'))
          _buildChartSection('Charts', musicData.modules['charts']! as List<Chart>),
         if (musicData.modules.containsKey('albums'))
          _buildAlbumSection('Albums', musicData.modules['albums']! as List<Album>),
        const SizedBox(height: 120), // Padding
      ],
    );
  }

  Widget _buildSearchResults(MusicData musicData) {
    if (musicData.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (musicData.searchResults.isEmpty) {
      return const Center(child: Text('No results found.'));
    }

    return ListView.builder(
      itemCount: musicData.searchResults.length,
      itemBuilder: (context, index) {
        final item = musicData.searchResults[index];
        if (item is Song) {
          return _buildSongItem(item);
        }
        if (item is Artist) {
          return _buildArtistItem(item, isTopResult: true);
        }
        if (item is Album) {
          return _buildAlbumItem(item);
        }
        if (item is Playlist) {
          return _buildPlaylistItem(item);
        }
        return const SizedBox.shrink();
      },
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

  Widget _buildSongSection(String title, List<Song> songs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        ...songs.map((song) => _buildSongItem(song)).toList(),
      ],
    );
  }

  Widget _buildHorizontalSection<T>(
      String title, List<T> items, Widget Function(T) itemBuilder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: itemBuilder(items[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumSection(String title, List<Album> albums) {
    return _buildHorizontalSection<Album>(
      title,
      albums,
      (album) => _buildGenericCard(
        title: album.title,
        subtitle: album.subtitle,
        imageUrl: album.imageUrl,
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
  }

  Widget _buildPlaylistSection(String title, List<Playlist> playlists) {
    return _buildHorizontalSection<Playlist>(
      title,
      playlists,
      (playlist) => _buildGenericCard(
        title: playlist.title,
        subtitle: playlist.subtitle,
        imageUrl: playlist.imageUrl,
        onTap: () {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistDetailsScreen(playlistId: playlist.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartSection(String title, List<Chart> charts) {
    return _buildHorizontalSection<Chart>(
      title,
      charts,
      (chart) => _buildGenericCard(
        title: chart.title,
        imageUrl: chart.imageUrl,
        onTap: () { /* TODO: Navigate to chart details */ },
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

   Widget _buildArtistItem(Artist artist, {bool isTopResult = false}) {
    return ListTile(
      leading: CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(artist.imageUrl),
        backgroundColor: Colors.transparent,
      ),
      title: Text(artist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Artist'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailsScreen(artistId: artist.id),
          ),
        );
      },
    );
  }

  Widget _buildAlbumItem(Album album) {
    return ListTile(
      leading: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: album.imageUrl,
          width: 56, height: 56, fit: BoxFit.cover,
          imageErrorBuilder: (c,e,s) => const Icon(Icons.album, size: 56),
        ),
      ),
      title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(album.subtitle ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailsScreen(albumId: album.id),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistItem(Playlist playlist) {
    return ListTile(
      leading: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: playlist.imageUrl,
          width: 56, height: 56, fit: BoxFit.cover,
          imageErrorBuilder: (c,e,s) => const Icon(Icons.playlist_play, size: 56),
        ),
      ),
      title: Text(playlist.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(playlist.subtitle ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
       onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistDetailsScreen(playlistId: playlist.id),
            ),
          );
        },
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
}
