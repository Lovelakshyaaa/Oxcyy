import 'package:oxcy/providers/music_provider.dart';

// A generic top-level result which could be a Song, Artist, or Album
abstract class TopQueryResult {}

class Artist extends TopQueryResult {
  final String id;
  final String name;
  final String imageUrl;
  final String type = 'artist';

  Artist({required this.id, required this.name, required this.imageUrl});
}

class Album extends TopQueryResult {
  final String id;
  final String title;
  final String imageUrl;
  final String? subtitle;
  final String type = 'album';

  Album({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
  });
}

class Playlist {
  final String id;
  final String title;
  final String imageUrl;
  final String? subtitle;

  Playlist({required this.id, required this.title, required this.imageUrl, this.subtitle});
}

class Chart {
  final String id;
  final String title;
  final String imageUrl;

  Chart({required this.id, required this.title, required this.imageUrl});
}


// We can extend the existing Song to be a TopQueryResult
class SearchSong extends Song implements TopQueryResult {
  SearchSong({
    required String id,
    required String title,
    required String artist,
    required String thumbUrl,
    required String type,
    Duration? duration,
  }) : super(
          id: id,
          title: title,
          artist: artist,
          thumbUrl: thumbUrl,
          type: type,
          duration: duration,
        );
}
