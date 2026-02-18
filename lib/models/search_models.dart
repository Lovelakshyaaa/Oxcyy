class SearchResult {
  final String id;
  final String title;
  final String? subtitle;
  final String type;
  final String imageUrl;

  SearchResult({required this.id, required this.title, this.subtitle, required this.type, required this.imageUrl});
}

class Artist {
  final String id;
  final String name;
  final String imageUrl;

  Artist({required this.id, required this.name, required this.imageUrl});
}

class Album {
  final String id;
  final String title;
  final String imageUrl;
  final String? subtitle;

  Album({required this.id, required this.title, required this.imageUrl, this.subtitle});
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

class Song {
  final String id; // The unique ID of the song from the API
  final String title;
  final String artist;
  final String thumbUrl;
  final String? type;
  final Duration? duration;
  String? downloadUrl; // Made optional

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    this.type,
    this.duration,
    this.downloadUrl, // Optional parameter
  });
}
