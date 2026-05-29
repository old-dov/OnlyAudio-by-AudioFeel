import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:media_kit/media_kit.dart' show Player, Media;

import '../../../core/models/track.dart';

/// Dual-player audio service:
/// - [_main]    : currently playing track (streams forwarded via StreamControllers)
/// - [_prefetch]: silently pre-buffers the next track
/// When the next track is requested and it matches the prefetched one, the
/// players are swapped so audio starts instantly (no libmpv init delay).
class AudioService {
  Player _main = Player();
  Player _prefetch = Player();
  final Random _random = Random();
  Future<void> _audioOp = Future.value();

  HttpServer? _server;
  int _serverPort = 0;
  int _issuedToken = 0;

  int _currentToken = 0;
  String? _currentTrackPath;

  int _nextToken = 0;
  String? _nextTrackPath;

  double _volume = 1.0;

  // Broadcast StreamControllers — PlayerController subscribes once to these.
  // When _main is swapped, we re-forward from the new player without changing
  // the subscriptions in PlayerController.
  final _posSC  = StreamController<Duration>.broadcast();
  final _durSC  = StreamController<Duration>.broadcast();
  final _playSC = StreamController<bool>.broadcast();
  final _compSC = StreamController<void>.broadcast();

  final List<StreamSubscription<dynamic>> _mainSubs = [];

  AudioService() {
    _subscribeMain();
    _startFileServer();
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _audioOp = _audioOp.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  int _reserveToken() {
    _issuedToken += 1;
    return _issuedToken;
  }

  // ── Re-wire stream controllers to whichever player is _main ────────────────
  void _subscribeMain() {
    for (final s in _mainSubs) {
      s.cancel();
    }
    _mainSubs.clear();
    _mainSubs.addAll([
      _main.stream.position.listen(_posSC.add),
      _main.stream.duration.listen(_durSC.add),
      _main.stream.playing.listen((v) {
        debugPrint('[AudioService] playing: $v');
        _playSC.add(v);
      }),
      _main.stream.buffering.listen(
        (v) => debugPrint('[AudioService] buffering: $v'),
      ),
      _main.stream.error.listen((e) => debugPrint('[AudioService] error: $e')),
      _main.stream.completed.where((c) => c).listen((_) => _compSC.add(null)),
    ]);
  }

  // ── HTTP file server ────────────────────────────────────────────────────────
  void _startFileServer() {
    HttpServer.bind(InternetAddress.loopbackIPv4, 0).then((server) {
      _server = server;
      _serverPort = server.port;
      debugPrint('[AudioService] file server on port $_serverPort');
      server.listen(
        (req) => unawaited(_serveFile(req)),
        onError: (Object e) => debugPrint('[AudioService] server error: $e'),
      );
    });
  }

  Future<void> _serveFile(HttpRequest request) async {
    try {
      final segments = request.uri.pathSegments;
      final token = int.tryParse(segments.firstOrNull ?? '');
      // Both current and next tokens are valid (prefetch player also requests)
      final path = (token == _currentToken)
          ? _currentTrackPath
          : (token != null && token == _nextToken)
              ? _nextTrackPath
              : null;

      if (token == null || path == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final file = File(path);
      final fileLength = await file.length();

      final lower = path.toLowerCase();
      final ct = lower.endsWith('.flac')
          ? 'audio/flac'
          : lower.endsWith('.ogg')
              ? 'audio/ogg'
              : lower.endsWith('.wav')
                  ? 'audio/wav'
                  : lower.endsWith('.aac')
                      ? 'audio/aac'
                      : lower.endsWith('.m4a') || lower.endsWith('.mp4')
                          ? 'audio/mp4'
                          : 'audio/mpeg';

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null) {
        final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (m != null) {
          final start = int.parse(m.group(1)!);
          final end = m.group(2)!.isNotEmpty
              ? int.parse(m.group(2)!)
              : fileLength - 1;
          request.response
            ..statusCode = HttpStatus.partialContent
            ..headers.contentType = ContentType.parse(ct)
            ..headers.set(
                HttpHeaders.contentRangeHeader, 'bytes $start-$end/$fileLength')
            ..headers.contentLength = end - start + 1
            ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
          await file.openRead(start, end + 1).pipe(request.response);
          return;
        }
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.parse(ct)
        ..headers.contentLength = fileLength
        ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      await file.openRead().pipe(request.response);
    } catch (e) {
      debugPrint('[AudioService] _serveFile error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  // ── Public streams ──────────────────────────────────────────────────────────
  Stream<Duration> get positionStream   => _posSC.stream;
  Stream<Duration> get durationStream   => _durSC.stream;
  Stream<bool>     get playingStream    => _playSC.stream;
  Stream<void>     get completionStream => _compSC.stream;

  // ── Volume ──────────────────────────────────────────────────────────────────
  Future<void> setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    return _main.setVolume((_volume * 100.0).clamp(0.0, 100.0));
  }

  // ── Pre-load next track silently in _prefetch ───────────────────────────────
  Future<void> preloadNext(Track track) async {
    return _serialize(() async {
      if (_serverPort == 0) return;
      if (_nextTrackPath == track.path && _nextToken > 0) return;

      _nextToken = _reserveToken();
      _nextTrackPath = track.path;
      final url = 'http://127.0.0.1:$_serverPort/$_nextToken';
      debugPrint('[AudioService] preload: ${track.path}');
      try {
        await _prefetch.setVolume(0);
        unawaited(_prefetch.open(Media(url), play: false));
      } catch (e) {
        debugPrint('[AudioService] preload error: $e');
        _nextToken = 0;
        _nextTrackPath = null;
      }
    });
  }

  // ── Open / swap ─────────────────────────────────────────────────────────────
  Future<void> playTrack(
    Track track, {
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    return _serialize(() async {
      // Fast path: track is pre-buffered and no seek needed → instant swap
      if (_nextToken > 0 &&
          _nextTrackPath == track.path &&
          initialPosition == null) {
        debugPrint('[AudioService] swap to preloaded: ${track.path}');
        _currentToken = _nextToken;
        _currentTrackPath = _nextTrackPath;
        _nextToken = 0;
        _nextTrackPath = null;

        final oldMain = _main;
        _main = _prefetch;
        _prefetch = Player(); // fresh player for the next preload

        _subscribeMain();
        await _main.setVolume((_volume * 100.0).clamp(0.0, 100.0));
        await oldMain.stop();
        if (autoPlay) unawaited(_main.play());
        unawaited(oldMain.dispose());
        return;
      }

      // Cancel in-progress prefetch if it's a different track
      if (_nextToken > 0) {
        _nextToken = 0;
        _nextTrackPath = null;
        await _prefetch.stop();
      }

      // Normal open
      var waited = 0;
      while (_serverPort == 0 && waited < 3000) {
        await Future.delayed(const Duration(milliseconds: 50));
        waited += 50;
      }
      _currentToken = _reserveToken();
      _currentTrackPath = track.path;
      final url = 'http://127.0.0.1:$_serverPort/$_currentToken';
      debugPrint('[AudioService] open (play=$autoPlay): ${track.path}');

      if (initialPosition != null && initialPosition > Duration.zero) {
        await _main.open(Media(url), play: autoPlay);
        await _main.seek(initialPosition);
      } else {
        await _main.open(Media(url), play: autoPlay);
      }
    });
  }

  Future<void> play()  => _serialize(() => _main.play());
  Future<void> pause() => _serialize(() => _main.pause());
  Future<void> stop()  => _serialize(() => _main.stop());
  Future<void> seek(Duration position) => _serialize(() => _main.seek(position));

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

  Future<void> dispose() async {
    for (final s in _mainSubs) {
      await s.cancel();
    }
    await _server?.close(force: true);
    await _main.dispose();
    await _prefetch.dispose();
    await _posSC.close();
    await _durSC.close();
    await _playSC.close();
    await _compSC.close();
  }
}
