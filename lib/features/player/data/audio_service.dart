import 'dart:math';

import 'package:just_audio/just_audio.dart';

import '../../../core/models/track.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  AudioPlayer get rawPlayer => _player;

  Future<void> dispose() => _player.dispose();

  Future<void> setVolume(double value) => _player.setVolume(value);

  Future<void> playTrack(Track track, {Duration? initialPosition}) async {
    await _player.setFilePath(track.path);
    if (initialPosition != null && initialPosition > Duration.zero) {
      await _player.seek(initialPosition);
    }
    await _player.play();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);

  int nextIndex({
    required int currentIndex,
    required int length,
    required bool shuffled,
  }) {
    if (length == 0) return 0;
    if (shuffled) return _random.nextInt(length);
    return (currentIndex + 1) % length;
  }

  int prevIndex({required int currentIndex, required int length}) {
    if (length == 0) return 0;
    return (currentIndex - 1 + length) % length;
  }
}
