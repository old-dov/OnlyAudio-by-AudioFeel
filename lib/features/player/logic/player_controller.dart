import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/player_state.dart';
import '../../../core/models/track.dart';
import '../../../core/services/storage_service.dart';
import '../../library/data/library_service.dart';
import '../data/audio_service.dart';
import '../data/metadata_service.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({
    required AudioService audioService,
    required MetadataService metadataService,
    required StorageService storageService,
    required LibraryService libraryService,
  })  : _audioService = audioService,
        _metadataService = metadataService,
        _storageService = storageService,
        _libraryService = libraryService;

  final AudioService _audioService;
  final MetadataService _metadataService;
  final StorageService _storageService;
  final LibraryService _libraryService;

  final List<Track> _playlist = [];
  PlayerStateModel _state = PlayerStateModel();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingStateSub;
  StreamSubscription<void>? _completionSub;
  StreamSubscription<Duration>? _durationSub;

  bool _ready = false;
  bool _isPaused = true;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  int? _preloadedNextIndex;
  String _cachedCoverPath = '';
  String _cachedCoverB64 = '';

  List<Track> get playlist => List.unmodifiable(_playlist);
  bool get ready => _ready;
  bool get isPaused => _isPaused;
  bool get isShuffled => _state.isShuffled;
  bool get isRepeat => _state.isRepeat;
  int get currentIndex => _state.currentIndex;
  double get volume => _state.volume;
  String get searchQuery => _state.searchQuery;
  String get sortMode => _state.sortMode;
  Duration get currentPosition => _currentPosition;
  // Fall back to the metadata duration if the stream hasn't fired yet
  Duration get currentDuration {
    if (_currentDuration.inMilliseconds > 0) return _currentDuration;
    final ms = currentTrack?.durationMs ?? 0;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }

  Track? get currentTrack =>
      _playlist.isNotEmpty && _state.currentIndex < _playlist.length
          ? _playlist[_state.currentIndex]
          : null;

  List<int> get visibleIndices {
    final indices = List<int>.generate(_playlist.length, (i) => i);
    switch (_state.sortMode) {
      case 'title':
        indices.sort((a, b) => _playlist[a]
            .title
            .toLowerCase()
            .compareTo(_playlist[b].title.toLowerCase()));
      case 'folder':
        indices.sort((a, b) => p
            .dirname(_playlist[a].path)
            .toLowerCase()
            .compareTo(p.dirname(_playlist[b].path).toLowerCase()));
      default:
        break;
    }
    final q = _state.searchQuery.toLowerCase().trim();
    if (q.isEmpty) return indices;
    return indices.where((i) {
      final t = _playlist[i];
      return t.title.toLowerCase().contains(q) ||
          t.path.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> init() async {
    _playlist
      ..clear()
      ..addAll(await _storageService.loadPlaylist());
    _state = await _storageService.loadState();
    if (_state.currentIndex >= _playlist.length) {
      _state.currentIndex = _playlist.isEmpty ? 0 : _playlist.length - 1;
    }
    await _audioService.setVolume(_state.volume);
    _positionSub = _audioService.positionStream.listen((pos) {
      _currentPosition = pos;
      _state.positionMs = pos.inMilliseconds;
      notifyListeners();
    });
    _durationSub = _audioService.durationStream.listen((dur) {
      if (dur != _currentDuration) {
        _currentDuration = dur;
        notifyListeners();
      }
    });
    _playingStateSub = _audioService.playingStream.listen((playing) {
      _isPaused = !playing;
      notifyListeners();
    });
    _completionSub = _audioService.completionStream.listen((_) {
      if (_state.isRepeat) {
        unawaited(playAt(_state.currentIndex));
      } else {
        unawaited(next());
      }
    });

    // Restore the current track (without auto-playing) so that the duration
    // stream is populated and pressing PLAY actually produces sound.
    if (_playlist.isNotEmpty) {
      final seekTo = _state.positionMs > 0
          ? Duration(milliseconds: _state.positionMs)
          : null;
      try {
        await _audioService.playTrack(
          _playlist[_state.currentIndex],
          initialPosition: seekTo,
          autoPlay: false,
        );
      } catch (e, st) {
        // ignore: avoid_print
        print('[PlayerController] init restore error: $e\n$st');
      }
    }

    _ready = true;
    _isPaused = true;
    notifyListeners();
  }

  Future<void> disposeController() async {
    await _persist();
    await _positionSub?.cancel();
    await _playingStateSub?.cancel();
    await _completionSub?.cancel();
    await _durationSub?.cancel();
    await _audioService.dispose();
  }

  // Full persist: playlist (with cover art) + state. Only call when playlist changes.
  Future<void> _persist() async {
    await _storageService.savePlaylist(_playlist);
    await _storageService.saveState(_state);
  }

  // Fast persist: state only (no cover art serialization). Use for playback changes.
  Future<void> _persistState() async {
    await _storageService.saveState(_state);
  }

  Future<void> addFiles() async {
    final paths = await _libraryService.pickFiles();
    await _addTrackPaths(paths);
  }

  Future<void> addFolder() async {
    final paths = await _libraryService.pickFolderAndScan();
    await _addTrackPaths(paths);
  }

  Future<void> _addTrackPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final known = _playlist.map((e) => e.path).toSet();
    for (final path in paths) {
      if (known.contains(path)) continue;
      known.add(path);
      _playlist.add(await _metadataService.fromPath(path));
    }
    await _persist();
    notifyListeners();
    if (_playlist.length == 1) {
      await playAt(0);
    }
  }

  Future<void> playAt(int index, {bool restorePosition = false}) async {
    if (_playlist.isEmpty) return;
    _state.currentIndex = index.clamp(0, _playlist.length - 1);
    final track = _playlist[_state.currentIndex];
    final seekTo =
        restorePosition ? Duration(milliseconds: _state.positionMs) : null;
    _currentDuration = Duration.zero;
    _currentPosition = Duration.zero;
    _isPaused = false;
    notifyListeners(); // Met à jour l'UI immédiatement (titre, pochette)
    try {
      await _audioService.playTrack(track, initialPosition: seekTo);
    } catch (e, st) {
      // ignore: avoid_print
      print('[PlayerController] playAt error: $e\n$st');
    }
    unawaited(_persistState());
    _schedulePreload();
  }

  void _schedulePreload() {
    if (_playlist.length < 2) return;
    final nextIdx = _audioService.nextIndex(
      currentIndex: _state.currentIndex,
      length: _playlist.length,
      shuffled: _state.isShuffled,
    );
    _preloadedNextIndex = nextIdx;
    unawaited(_audioService.preloadNext(_playlist[nextIdx]));
  }

  Future<void> playPause() async {
    if (_playlist.isEmpty) return;
    if (_isPaused) {
      await _audioService.play();
      _isPaused = false;
    } else {
      await _audioService.pause();
      _isPaused = true;
    }
    await _persistState();
    notifyListeners();
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    final idx =
        (_preloadedNextIndex != null && _preloadedNextIndex! < _playlist.length)
            ? _preloadedNextIndex!
            : _audioService.nextIndex(
                currentIndex: _state.currentIndex,
                length: _playlist.length,
                shuffled: _state.isShuffled,
              );
    _preloadedNextIndex = null;
    await playAt(idx);
  }

  Future<void> prev() async {
    if (_playlist.isEmpty) return;
    final idx = _audioService.prevIndex(
      currentIndex: _state.currentIndex,
      length: _playlist.length,
    );
    await playAt(idx);
  }

  Future<void> setVolume(double value) async {
    _state.volume = value.clamp(0, 1);
    await _audioService.setVolume(_state.volume);
    await _persistState();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
    _state.positionMs = position.inMilliseconds;
    await _persistState();
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _state.isShuffled = !_state.isShuffled;
    await _persist();
    notifyListeners();
  }

  Future<void> toggleRepeat() async {
    _state.isRepeat = !_state.isRepeat;
    await _persist();
    notifyListeners();
  }

  Future<void> cycleSortMode() async {
    const modes = ['added', 'title', 'folder'];
    final pos = modes.indexOf(_state.sortMode);
    _state.sortMode = modes[(pos + 1) % modes.length];
    await _persist();
    notifyListeners();
  }

  Future<void> setSearchQuery(String value) async {
    _state.searchQuery = value;
    await _persist();
    notifyListeners();
  }

  Future<void> removeCurrent() async {
    if (_playlist.isEmpty) return;
    final removed = _state.currentIndex;
    _playlist.removeAt(removed);
    if (_playlist.isEmpty) {
      _state.currentIndex = 0;
      _state.positionMs = 0;
      await _audioService.stop();
      _isPaused = true;
    } else {
      if (_state.currentIndex >= _playlist.length) {
        _state.currentIndex = _playlist.length - 1;
      }
      await playAt(_state.currentIndex);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clearPlaylist() async {
    _playlist.clear();
    _state.currentIndex = 0;
    _state.positionMs = 0;
    _isPaused = true;
    await _audioService.stop();
    await _persist();
    notifyListeners();
  }

  void jumpToNowPlaying() {
    notifyListeners();
  }

  Future<Map<String, dynamic>> remoteStatusPayload() async {
    final current = currentTrack;
    if (current == null) {
      _cachedCoverPath = '';
      _cachedCoverB64 = '';
    } else if (current.path != _cachedCoverPath) {
      _cachedCoverPath = current.path;
      final bytes = await _metadataService.coverBytes(current.path);
      _cachedCoverB64 = bytes != null ? base64Encode(bytes) : '';
    }
    return {
      'title': current?.title ?? '',
      'artist': current?.artist ?? '',
      'album': current?.album ?? '',
      'year': current?.year,
      'pos': _currentPosition.inMilliseconds,
      'dur': currentDuration.inMilliseconds,
      'cover_b64': _cachedCoverB64,
      'is_playing': !_isPaused,
      'index': _state.currentIndex,
    };
  }

  Map<String, dynamic> remotePlaylistPayload() {
    return {
      'tracks': List.generate(
          _playlist.length,
          (i) => {
                'index': i,
                'title': _playlist[i].title,
                'folder': p.basename(p.dirname(_playlist[i].path)),
              }),
      'current_index': _state.currentIndex,
      'is_shuffled': _state.isShuffled,
      'is_repeat': _state.isRepeat,
      'volume': _state.volume,
    };
  }

  String exportPlaylistJson() =>
      jsonEncode(_playlist.map((t) => t.toJson()).toList());
}
