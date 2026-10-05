import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../logic/player_controller.dart';

/// Publishes OnlyAudio to the operating system media session.
///
/// Bluetooth remotes and headset buttons are translated by the operating
/// system into the callbacks implemented by [_OnlyAudioMediaHandler].
class SystemMediaService {
  SystemMediaService._(this._handler);

  final _OnlyAudioMediaHandler _handler;

  static Future<SystemMediaService> initialize(
    PlayerController controller,
  ) async {
    late _OnlyAudioMediaHandler implementation;

    await AudioService.init(
      builder: () {
        implementation = _OnlyAudioMediaHandler(controller);
        return implementation;
      },
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.audiofeel.onlyaudio.media',
        androidNotificationChannelName: 'OnlyAudio',
      ),
    );

    await implementation.synchronize(immediate: true);
    return SystemMediaService._(implementation);
  }

  Future<void> dispose() => _handler.disposeHandler();
}

class _OnlyAudioMediaHandler extends BaseAudioHandler with SeekHandler {
  _OnlyAudioMediaHandler(this._controller) {
    _controller.addListener(_onControllerChanged);
  }

  final PlayerController _controller;
  Timer? _syncTimer;
  String? _lastTrackPath;
  bool? _lastPlaying;
  Duration? _lastDuration;
  bool _disposed = false;

  void _onControllerChanged() {
    if (_disposed) return;

    final trackChanged = _lastTrackPath != _controller.currentTrack?.path;
    final playingChanged = _lastPlaying != !_controller.isPaused;
    final durationChanged = _lastDuration != _controller.currentDuration;

    if (trackChanged || playingChanged || durationChanged) {
      unawaited(synchronize(immediate: true));
      return;
    }

    // media_kit can emit position updates many times per second. System media
    // controls only need a periodic anchor and extrapolate between updates.
    _syncTimer ??= Timer(const Duration(milliseconds: 500), () {
      _syncTimer = null;
      unawaited(synchronize());
    });
  }

  Future<void> synchronize({bool immediate = false}) async {
    if (_disposed) return;
    if (immediate) {
      _syncTimer?.cancel();
      _syncTimer = null;
    }

    final track = _controller.currentTrack;
    final playing = !_controller.isPaused;
    final duration = _controller.currentDuration;

    try {
      if (track == null) {
        _lastTrackPath = null;
        _lastPlaying = false;
        _lastDuration = Duration.zero;
        mediaItem.add(null);
        playbackState.add(
          PlaybackState(
            processingState: AudioProcessingState.idle,
            playing: false,
          ),
        );
        return;
      }

      if (_lastTrackPath != track.path || _lastDuration != duration) {
        mediaItem.add(
          MediaItem(
            id: track.path,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: duration,
          ),
        );
      }

      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekBackward,
            MediaAction.seekForward,
          },
          processingState: AudioProcessingState.ready,
          playing: playing,
          updatePosition: _controller.currentPosition,
          speed: 1,
          queueIndex: _controller.currentIndex,
        ),
      );

      _lastTrackPath = track.path;
      _lastPlaying = playing;
      _lastDuration = duration;
    } catch (error, stackTrace) {
      debugPrint('[SystemMediaService] synchronization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> play() async {
    if (_controller.isPaused) {
      await _controller.playPause();
    }
    await synchronize(immediate: true);
  }

  @override
  Future<void> pause() async {
    if (!_controller.isPaused) {
      await _controller.playPause();
    }
    await synchronize(immediate: true);
  }

  @override
  Future<void> skipToNext() async {
    await _controller.next();
    await synchronize(immediate: true);
  }

  @override
  Future<void> skipToPrevious() async {
    await _controller.prev();
    await synchronize(immediate: true);
  }

  @override
  Future<void> seek(Duration position) async {
    final duration = _controller.currentDuration;
    final target = duration > Duration.zero && position > duration
        ? duration
        : position < Duration.zero
            ? Duration.zero
            : position;
    await _controller.seek(target);
    await synchronize(immediate: true);
  }

  Future<void> disposeHandler() async {
    if (_disposed) return;
    _disposed = true;
    _syncTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    mediaItem.add(null);
    await super.stop();
  }
}
