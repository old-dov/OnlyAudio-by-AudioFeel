import 'dart:convert';
import 'dart:io';

import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/track.dart';

class MetadataService {
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
        coverBase64: metadata.albumArt == null
            ? ''
            : base64Encode(metadata.albumArt!),
      );
    } catch (_) {
      return Track(path: trackPath, title: p.basename(trackPath));
    }
  }

  Future<bool> exists(String trackPath) async {
    return File(trackPath).exists();
  }
}
