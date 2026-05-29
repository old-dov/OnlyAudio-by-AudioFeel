import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/track.dart';

class MetadataService {
  Future<Uint8List?> coverBytes(String trackPath) async {
    try {
      final metadata = await MetadataRetriever.fromFile(File(trackPath));
      return metadata.albumArt;
    } catch (_) {
      return null;
    }
  }

  Future<Track> fromPath(String trackPath) async {
    try {
      final metadata = await MetadataRetriever.fromFile(File(trackPath));
      return Track(
        path: trackPath,
        title: metadata.trackName ?? p.basename(trackPath),
        artist: metadata.trackArtistNames?.join(', ') ?? 'Unknown Artist',
        album: metadata.albumName ?? 'Unknown Album',
        durationMs: metadata.trackDuration ?? 0,
        year: metadata.year,
      );
    } catch (_) {
      return Track(path: trackPath, title: p.basename(trackPath));
    }
  }

  Future<bool> exists(String trackPath) async {
    return File(trackPath).exists();
  }
}
