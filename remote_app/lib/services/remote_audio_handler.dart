import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';

import 'api_client.dart';

/// AudioHandler that drives the Android media notification and the lock-screen controls.
/// It doesn't play audio locally — it sends commands to the desktop player.
class RemoteAudioHandler extends BaseAudioHandler with SeekHandler {
  RemoteAudioHandler();

  ApiClient? _api;
  bool _playing = false;

  // What the notification currently shows, so an unchanged poll (every 0.8 s) does not
  // rebuild it.
  String _shownTitle = '';
  String _shownArtist = '';
  String _shownAlbum = '';
  int _shownDurationMs = -1;
  String _shownCover = '';
  Uri? _artUri;
  File? _coverFile;
  int _coverCounter = 0;
  bool _shownPlaying = false;
  bool _shownConnected = true;
  int _shownPositionMs = 0;
  DateTime _shownAt = DateTime.fromMillisecondsSinceEpoch(0);

  void attachApi(ApiClient api) {
    _api = api;
  }

  /// Update the notification with the current track, cover and playback state.
  void updateNotification({
    required String title,
    required String artist,
    required String album,
    required Duration position,
    required Duration duration,
    String coverBase64 = '',
    bool connected = true,
  }) {
    final trackChanged = title != _shownTitle ||
        artist != _shownArtist ||
        album != _shownAlbum ||
        duration.inMilliseconds != _shownDurationMs ||
        coverBase64 != _shownCover;
    if (trackChanged) {
      _shownTitle = title;
      _shownArtist = artist;
      _shownAlbum = album;
      _shownDurationMs = duration.inMilliseconds;
      if (coverBase64 != _shownCover) {
        _shownCover = coverBase64;
        _artUri = _writeCover(coverBase64);
      }
      mediaItem.add(MediaItem(
        id: 'remote_track',
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        artUri: _artUri,
      ));
    }

    // The system moves the progress bar by itself between two updates: only push the
    // state when something changed, or when the position drifted from that extrapolation.
    final now = DateTime.now();
    final expectedMs = _shownPositionMs +
        (_shownPlaying ? now.difference(_shownAt).inMilliseconds : 0);
    final drifted = (position.inMilliseconds - expectedMs).abs() > 1500;
    if (trackChanged ||
        _playing != _shownPlaying ||
        connected != _shownConnected ||
        drifted) {
      _shownPlaying = _playing;
      _shownConnected = connected;
      _shownPositionMs = position.inMilliseconds;
      _shownAt = now;
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        // Desktop unreachable: show the player as buffering rather than as working.
        processingState:
            connected ? AudioProcessingState.ready : AudioProcessingState.buffering,
        playing: _playing,
        updatePosition: position,
      ));
    }
  }

  /// The desktop player stopped answering: keep what was shown but mark it as not ready.
  void markDisconnected() {
    if (_shownTitle.isEmpty || !_shownConnected) return;
    updateNotification(
      title: _shownTitle,
      artist: _shownArtist,
      album: _shownAlbum,
      position: Duration(milliseconds: _shownPositionMs),
      duration: Duration(milliseconds: max(0, _shownDurationMs)),
      coverBase64: _shownCover,
      connected: false,
    );
  }

  /// The cover arrives as base64 in the status; the notification needs a URI, so it goes to a
  /// cache file. A new name each time, because Android caches artwork by URI.
  Uri? _writeCover(String coverBase64) {
    final previous = _coverFile;
    _coverFile = null;
    if (previous != null) {
      try {
        previous.deleteSync();
      } catch (_) {}
    }
    if (coverBase64.isEmpty) return null;
    try {
      final file = File(
        '${Directory.systemTemp.path}/remote_cover_${_coverCounter++}.img',
      );
      file.writeAsBytesSync(base64Decode(coverBase64), flush: true);
      _coverFile = file;
      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  void setPlaying(bool playing) {
    _playing = playing;
  }

  @override
  Future<void> play() async {
    if (_api == null) return;
    if (!_playing) {
      await _api!.playPause();
    }
  }

  @override
  Future<void> pause() async {
    if (_api == null) return;
    if (_playing) {
      await _api!.playPause();
    }
  }

  @override
  Future<void> skipToNext() async {
    await _api?.next();
  }

  @override
  Future<void> skipToPrevious() async {
    await _api?.prev();
  }

  @override
  Future<void> seek(Duration position) async {
    await _api?.seek(position.inMilliseconds);
  }

  @override
  Future<void> stop() async {
    _shownTitle = '';
    _shownCover = '';
    _shownPlaying = false;
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }
}
