import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class RemoteStatus {
  final String title;
  final String artist;
  final String album;
  final int posMs;
  final int durMs;
  final String coverBase64;
  final bool isPlaying;
  final int? year;

  const RemoteStatus({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.posMs = 0,
    this.durMs = 0,
    this.coverBase64 = '',
    this.isPlaying = false,
    this.year,
  });

  factory RemoteStatus.fromJson(Map<String, dynamic> json) {
    return RemoteStatus(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      posMs: (json['pos'] as num?)?.toInt() ?? 0,
      durMs: (json['dur'] as num?)?.toInt() ?? 0,
      coverBase64: json['cover_b64'] as String? ?? '',
      isPlaying: json['is_playing'] as bool? ?? false,
      year: json['year'] as int?,
    );
  }
}

class RemoteTrack {
  final int index;
  final String title;
  final String folder;

  const RemoteTrack({
    required this.index,
    required this.title,
    required this.folder,
  });

  factory RemoteTrack.fromJson(Map<String, dynamic> json) {
    return RemoteTrack(
      index: json['index'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      folder: json['folder'] as String? ?? '',
    );
  }
}

class RemotePlaylist {
  final List<RemoteTrack> tracks;
  final int currentIndex;
  final bool isShuffled;
  final bool isRepeat;
  final double volume;

  const RemotePlaylist({
    this.tracks = const [],
    this.currentIndex = 0,
    this.isShuffled = false,
    this.isRepeat = false,
    this.volume = 0.5,
  });

  factory RemotePlaylist.fromJson(Map<String, dynamic> json) {
    final list = (json['tracks'] as List<dynamic>?)
            ?.map((e) => RemoteTrack.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return RemotePlaylist(
      tracks: list,
      currentIndex: json['current_index'] as int? ?? 0,
      isShuffled: json['is_shuffled'] as bool? ?? false,
      isRepeat: json['is_repeat'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl;
  final http.Client _client = http.Client();

  static const _timeout = Duration(seconds: 3);

  Future<RemoteStatus> fetchStatus() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/status'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return RemoteStatus.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Status request failed: ${response.statusCode}');
  }

  Future<RemotePlaylist> fetchPlaylist() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/playlist'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return RemotePlaylist.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Playlist request failed: ${response.statusCode}');
  }

  Future<void> playPause() async {
    await _client.get(Uri.parse('$baseUrl/play_pause')).timeout(_timeout);
  }

  Future<void> prev() async {
    await _client.get(Uri.parse('$baseUrl/prev')).timeout(_timeout);
  }

  Future<void> next() async {
    await _client.get(Uri.parse('$baseUrl/next')).timeout(_timeout);
  }

  Future<void> volUp() async {
    await _client.get(Uri.parse('$baseUrl/vol_up')).timeout(_timeout);
  }

  Future<void> volDown() async {
    await _client.get(Uri.parse('$baseUrl/vol_down')).timeout(_timeout);
  }

  Future<void> toggleShuffle() async {
    await _client.get(Uri.parse('$baseUrl/shuffle')).timeout(_timeout);
  }

  Future<void> toggleRepeat() async {
    await _client.get(Uri.parse('$baseUrl/repeat')).timeout(_timeout);
  }

  Future<void> seek(int positionMs) async {
    await _client
        .get(Uri.parse('$baseUrl/seek/$positionMs'))
        .timeout(_timeout);
  }

  Future<void> playIndex(int index) async {
    await _client
        .get(Uri.parse('$baseUrl/play_index/$index'))
        .timeout(_timeout);
  }

  Future<bool> discover() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/discover'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['app'] == 'OnlyAudio';
      }
    } catch (_) {
      // not reachable
    }
    return false;
  }

  void dispose() {
    _client.close();
  }
}
