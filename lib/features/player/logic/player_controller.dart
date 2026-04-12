import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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
  StreamSubscription<PlayerState>? _playerStateSub;

  bool _ready = false;
  bool _isPaused = true;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;

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
  Duration get currentDuration => _currentDuration;
  Track? get currentTrack =>
      _playlist.isNotEmpty && _state.currentIndex < _playlist.length
          ? _playlist[_state.currentIndex]
          : null;

  List<int> get visibleIndices {
    final indices = List<int>.generate(_playlist.length, (i) => i);
    switch (_state.sortMode) {
      case 'title':
        indices.sort((a, b) => _playlist[a].title
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
    _positionSub = _audioService.rawPlayer.positionStream.listen((pos) {
      _currentPosition = pos;
      _state.positionMs = pos.inMilliseconds;
      notifyListeners();
    });
    _playerStateSub = _audioService.rawPlayer.playerStateStream.listen((st) {
      _isPaused = !st.playing;
      if (st.processingState == ProcessingState.completed) {
        if (_state.isRepeat) {
          unawaited(playAt(_state.currentIndex));
        } else {
          unawaited(next());
        }
      }
      notifyListeners();
    });
    _currentDuration = _audioService.rawPlayer.duration ?? Duration.zero;
    _ready = true;
    notifyListeners();
  }

  Future<void> disposeController() async {
    await _persist();
    await _positionSub?.cancel();
    await _playerStateSub?.cancel();
    await _audioService.dispose();
  }

  Future<void> _persist() async {
    await _storageService.savePlaylist(_playlist);
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
    await _audioService.playTrack(track, initialPosition: seekTo);
    _currentDuration = _audioService.rawPlayer.duration ?? Duration.zero;
    _isPaused = false;
    await _persist();
    notifyListeners();
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
    await _persist();
    notifyListeners();
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    final idx = _audioService.nextIndex(
      currentIndex: _state.currentIndex,
      length: _playlist.length,
      shuffled: _state.isShuffled,
    );
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
    await _persist();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
    _state.positionMs = position.inMilliseconds;
    await _persist();
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

  Map<String, dynamic> remoteStatusPayload() {
    final current = currentTrack;
    return {
      'title': current?.title ?? '',
      'artist': current?.artist ?? '',
      'album': current?.album ?? '',
      'pos': _currentPosition.inMilliseconds,
      'dur': _currentDuration.inMilliseconds,
      'cover_b64': current?.coverBase64 ?? '',
    };
  }

  String exportPlaylistJson() => jsonEncode(_playlist.map((t) => t.toJson()).toList());
}
