import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_data_provider.dart';
import 'package:provider/provider.dart';

class SearchScreenDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F0C29),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1D1B3E),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headline6: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final musicData = Provider.of<MusicData>(context, listen: false);
    musicData.search(query);

    return Consumer<MusicData>(
      builder: (context, data, child) {
        if (data.isSearching) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.errorMessage != null) {
          return Center(child: Text(data.errorMessage!));
        }
        return _buildSearchResults(data.searchResults);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0C29),
      child: const Center(
        child: Text('Search for songs, artists, albums...'),
      ),
    );
  }

  Widget _buildSearchResults(List<dynamic> results) {
    return Container(
      color: const Color(0xFF0F0C29),
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          if (item is Song) {
            return ListTile(
              leading: Image.network(item.thumbUrl, width: 50, height: 50),
              title: Text(item.title),
              subtitle: Text(item.artist),
              onTap: () {
                // Handle song tap
              },
            );
          } else if (item is Artist) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(item.imageUrl),
              ),
              title: Text(item.name),
              onTap: () {
                // Handle artist tap
              },
            );
          } else if (item is Album) {
            return ListTile(
              leading: Image.network(item.imageUrl, width: 50, height: 50),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              onTap: () {
                // Handle album tap
              },
            );
          } else if (item is Playlist) {
            return ListTile(
              leading: Image.network(item.imageUrl, width: 50, height: 50),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              onTap: () {
                // Handle playlist tap
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
