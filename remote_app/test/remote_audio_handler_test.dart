import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onlyaudio_remote/services/remote_audio_handler.dart';

void main() {
  const song = Duration(minutes: 3);

  void push(RemoteAudioHandler h, {String title = 'A', int posMs = 0, bool connected = true}) {
    h.updateNotification(
      title: title,
      artist: 'Artist',
      album: 'Album',
      position: Duration(milliseconds: posMs),
      duration: song,
      connected: connected,
    );
  }

  test('an unchanged poll does not rebuild the notification', () {
    final h = RemoteAudioHandler();
    var items = 0, states = 0;
    h.mediaItem.skip(1).listen((_) => items++);
    h.playbackState.skip(1).listen((_) => states++);

    h.setPlaying(true);
    push(h);
    push(h, posMs: 800);
    push(h, posMs: 1000);
    return Future<void>.delayed(Duration.zero).then((_) {
      expect(items, 1);
      expect(states, 1);
    });
  });

  test('a new track, a pause and a seek each update the notification', () async {
    final h = RemoteAudioHandler();
    final titles = <String?>[];
    final playing = <bool>[];
    h.mediaItem.skip(1).listen((m) => titles.add(m?.title));
    h.playbackState.skip(1).listen((s) => playing.add(s.playing));

    h.setPlaying(true);
    push(h);
    push(h, title: 'B');
    h.setPlaying(false);
    push(h, title: 'B', posMs: 900);
    push(h, title: 'B', posMs: 60000);
    await Future<void>.delayed(Duration.zero);

    expect(titles, ['A', 'B']);
    expect(playing, [true, true, false, false]);
  });

  test('an unreachable desktop shows as buffering, then recovers', () async {
    final h = RemoteAudioHandler();
    final states = <AudioProcessingState>[];
    h.playbackState.skip(1).listen((s) => states.add(s.processingState));

    h.setPlaying(true);
    push(h);
    h.markDisconnected();
    push(h);
    await Future<void>.delayed(Duration.zero);

    expect(states, [
      AudioProcessingState.ready,
      AudioProcessingState.buffering,
      AudioProcessingState.ready,
    ]);
  });

  test('nothing is shown when the desktop was never reached', () async {
    final h = RemoteAudioHandler();
    var states = 0;
    h.playbackState.skip(1).listen((_) => states++);
    h.markDisconnected();
    await Future<void>.delayed(Duration.zero);
    expect(states, 0);
  });
}
