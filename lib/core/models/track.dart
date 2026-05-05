class Track {
  Track({
    required this.path,
    required this.title,
    this.artist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.durationMs = 0,
    this.year,
    this.coverBase64 = '',
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int? year;
  final String coverBase64;

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'year': year,
      'coverBase64': coverBase64,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      path: json['path'] as String,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? 'Unknown Album',
      durationMs: json['durationMs'] as int? ?? 0,
      year: json['year'] as int?,
      coverBase64: json['coverBase64'] as String? ?? '',
    );
  }
}
