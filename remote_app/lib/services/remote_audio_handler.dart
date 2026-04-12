import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'api_client.dart';

/// AudioHandler that drives the Android media notification bar.
/// It doesn't play audio locally — it sends commands to the desktop player.
class RemoteAudioHandler extends BaseAudioHandler with SeekHandler {
  RemoteAudioHandler();

  ApiClient? _api;
  bool _playing = false;

  void attachApi(ApiClient api) {
    _api = api;
  }

  /// Update the notification bar with current track info.
  void updateNotification({
    required String title,
    required String artist,
    required String album,
    required Duration position,
    required Duration duration,
  }) {
    mediaItem.add(MediaItem(
      id: 'remote_track',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
    ));
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
      processingState: AudioProcessingState.ready,
      playing: _playing,
      updatePosition: position,
    ));
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
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }
}
