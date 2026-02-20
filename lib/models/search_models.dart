
// Defines the data models used throughout the application, with fromJson constructors
// for robust parsing of the data from the JioSaavn API.

// Represents a generic link with quality and URL, used for images and downloads.
class Link {
  final String quality;
  final String url;

  Link({required this.quality, required this.url});

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      quality: json['quality'] as String? ?? 'low',
      url: (json['url'] as String? ?? '').replaceAll('http:', 'https'),
    );
  }
  Map<String, dynamic> toJson() => {
        'quality': quality,
        'url': url,
      };
}

// Base class for a searchable item (e.g., Song, Album).
abstract class SearchResult {
  final String id;
  final String name;
  final String type;
  final List<Link> image;

  SearchResult({
    required this.id,
    required this.name,
    required this.type,
    required this.image,
  });

  String get highQualityImageUrl =>
      image.firstWhere((l) => l.quality == '500x500', orElse: () => image.last).url;
}

// Represents an Artist entity from the API.
class Artist extends SearchResult {
  Artist({
    required String id,
    required String name,
    required String type,
    required List<Link> image,
  }) : super(id: id, name: name, type: type, image: image);

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? 'Unknown Artist',
      type: json['type'] as String? ?? 'artist',
      image: (json['image'] as List<dynamic>? ?? [])
          .map((i) => Link.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
    Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'image': image.map((e) => e.toJson()).toList(),
      };
}

// Represents an Album entity from the API.
class Album extends SearchResult {
  final List<Artist> artists;

  Album({
    required String id,
    required String name,
    required String type,
    required List<Link> image,
    required this.artists,
  }) : super(id: id, name: name, type: type, image: image);

  factory Album.fromJson(Map<String, dynamic> json) {
    var artistsData = (json['artists']?['primary'] as List<dynamic>?) ?? 
                      (json['artists'] as List<dynamic>?) ?? 
                      [];
                      
    return Album(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? 'Unknown Album',
      type: json['type'] as String? ?? 'album',
      image: (json['image'] as List<dynamic>? ?? [])
          .map((i) => Link.fromJson(i as Map<String, dynamic>))
          .toList(),
      artists: artistsData
          .map((a) => Artist.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  String get artistNames => artists.map((a) => a.name).join(', ');
}

// Represents a Playlist entity from the API.
class Playlist extends SearchResult {
  Playlist({
    required String id,
    required String name,
    required String type,
    required List<Link> image,
  }) : super(id: id, name: name, type: type, image: image);

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? 'Unknown Playlist',
      type: json['type'] as String? ?? 'playlist',
      image: (json['image'] as List<dynamic>? ?? [])
          .map((i) => Link.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Represents a Chart entity from the API.
class Chart extends SearchResult {
  Chart({
    required String id,
    required String name,
    required String type,
    required List<Link> image,
  }) : super(id: id, name: name, type: type, image: image);

  factory Chart.fromJson(Map<String, dynamic> json) {
    return Chart(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? 'Unknown Chart',
      type: json['type'] as String? ?? 'chart',
      image: (json['image'] as List<dynamic>? ?? [])
          .map((i) => Link.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Represents a Song entity, including download and artist details.
class Song extends SearchResult {
  final int? duration;
  final List<Artist> artists;
  final List<Link> downloadUrl;

  Song({
    required String id,
    required String name,
    required String type,
    required List<Link> image,
    this.duration,
    required this.artists,
    required this.downloadUrl,
  }) : super(id: id, name: name, type: type, image: image);

  factory Song.fromJson(Map<String, dynamic> json) {
    var artistsData = (json['artists']?['primary'] as List<dynamic>?) ?? 
                      (json['primaryArtists'] as List<dynamic>?) ??
                      [];
                      
    return Song(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Song',
      type: json['type'] as String? ?? 'song',
      image: (json['image'] as List<dynamic>? ?? [])
          .map((i) => Link.fromJson(i as Map<String, dynamic>))
          .toList(),
      duration: int.tryParse(json['duration']?.toString() ?? '0'),
      artists: artistsData
          .map((a) => a is Map<String, dynamic> ? Artist.fromJson(a) : Artist(id: '', name: a.toString(), type: 'artist', image: []))
          .toList(),
      downloadUrl: (json['downloadUrl'] as List<dynamic>? ?? [])
          .map((u) => Link.fromJson(u as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'image': image.map((e) => e.toJson()).toList(),
        'duration': duration,
        'artists': artists.map((e) => e.toJson()).toList(),
        'downloadUrl': downloadUrl.map((e) => e.toJson()).toList(),
      };


  String get artistNames => artists.map((a) => a.name).join(', ');
  String? get highQualityStreamUrl {
      final hq = downloadUrl.firstWhere((l) => l.quality == '320kbps', orElse: () => downloadUrl.last);
      return hq.url;
  }
}
