import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/remote_audio_handler.dart';
import 'connection_screen.dart';
import 'playlist_screen.dart';

class RemotePlayerScreen extends StatefulWidget {
  const RemotePlayerScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<RemotePlayerScreen> createState() => _RemotePlayerScreenState();
}

class _RemotePlayerScreenState extends State<RemotePlayerScreen> {
  RemoteStatus _status = const RemoteStatus();
  RemotePlaylist _playlist = const RemotePlaylist();
  Timer? _pollTimer;
  bool _connected = true;
  bool _seeking = false;
  double _seekValue = 0;

  RemoteAudioHandler? _audioHandler;

  // Cached cover image to avoid flickering on every poll
  String _lastCoverBase64 = '';
  Uint8List? _cachedCoverBytes;

  @override
  void initState() {
    super.initState();
    _audioHandler = audioHandlerGlobal;
    _audioHandler?.attachApi(widget.api);
    _startPolling();
  }

  void _startPolling() {
    _fetchAll();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _fetchAll();
    });
  }

  Future<void> _fetchAll() async {
    try {
      final status = await widget.api.fetchStatus();
      final playlist = await widget.api.fetchPlaylist();
      if (!mounted) return;

      setState(() {
        _status = status;
        _playlist = playlist;
        _connected = true;
      });

      // Update notification bar
      _audioHandler?.setPlaying(!_isPaused);
      _audioHandler?.updateNotification(
        title: status.title.isNotEmpty ? status.title : 'OnlyAudio',
        artist: status.artist.isNotEmpty ? status.artist : 'Artiste Inconnu',
        album: status.album.isNotEmpty ? status.album : 'Album Inconnu',
        position: Duration(milliseconds: max(0, status.posMs)),
        duration: Duration(milliseconds: max(0, status.durMs)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _connected = false);
    }
  }

  bool get _isPaused {
    // If position isn't changing between polls, track is paused.
    // Simple heuristic — the desktop doesn't expose isPaused directly.
    return _status.posMs <= 0 && _status.title.isNotEmpty;
  }

  void _disconnect() {
    _pollTimer?.cancel();
    _audioHandler?.stop();
    widget.api.dispose();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectionScreen()),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '0:00';
    final m = ms ~/ 60000;
    final s = (ms ~/ 1000) % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _updateCoverCache() {
    if (_status.coverBase64 != _lastCoverBase64) {
      _lastCoverBase64 = _status.coverBase64;
      _cachedCoverBytes = _status.coverBase64.isNotEmpty
          ? base64Decode(_status.coverBase64)
          : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateCoverCache();
    final coverBytes = _cachedCoverBytes;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Top bar ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _connected
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    color: _connected
                        ? const Color(0xFF18D1B5)
                        : Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connected ? 'Connecté' : 'Déconnecté',
                      style: TextStyle(
                        color: _connected
                            ? const Color(0xFF18D1B5)
                            : Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_play_rounded, size: 28),
                    tooltip: 'Playlist',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistScreen(
                            api: widget.api,
                            playlist: _playlist,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_off_rounded, size: 22),
                    tooltip: 'Déconnecter',
                    onPressed: _disconnect,
                  ),
                ],
              ),
            ),

            // --- Cover art ---
            Expanded(
              flex: 5,
              child: Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF161D29),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    image: coverBytes != null
                        ? DecorationImage(
                            image: MemoryImage(coverBytes),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: coverBytes == null
                      ? const Icon(Icons.library_music_rounded,
                          size: 100, color: Colors.white24)
                      : null,
                ),
              ),
            ),

            // --- Track info ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    _status.title.isNotEmpty
                        ? _status.title
                        : 'Aucun titre',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _status.artist.isNotEmpty
                        ? _status.artist
                        : 'Artiste Inconnu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF31A9FF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _status.album.isNotEmpty
                        ? _status.album
                        : 'Album Inconnu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- Seek bar ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: const Color(0xFF31A9FF),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFF31A9FF),
                    ),
                    child: Slider(
                      value: _seeking
                          ? _seekValue
                          : min(
                              max(0, _status.posMs.toDouble()),
                              max(1, _status.durMs.toDouble()),
                            ),
                      max: max(1, _status.durMs.toDouble()),
                      onChangeStart: (v) {
                        _seeking = true;
                        _seekValue = v;
                      },
                      onChanged: (v) {
                        setState(() => _seekValue = v);
                      },
                      onChangeEnd: (v) {
                        _seeking = false;
                        widget.api.seek(v.toInt());
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(
                              _seeking ? _seekValue.toInt() : _status.posMs),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        Text(
                          _formatDuration(_status.durMs),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // --- Main controls ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shuffle
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: _playlist.isShuffled
                        ? const Color(0xFF18D1B5)
                        : Colors.white38,
                    size: 24,
                  ),
                  onPressed: () => widget.api.toggleShuffle(),
                ),
                const SizedBox(width: 8),
                // Prev
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded,
                      color: Colors.white, size: 40),
                  onPressed: () => widget.api.prev(),
                ),
                const SizedBox(width: 8),
                // Play/Pause
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF31A9FF),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 38,
                    ),
                    color: Colors.white,
                    onPressed: () => widget.api.playPause(),
                  ),
                ),
                const SizedBox(width: 8),
                // Next
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded,
                      color: Colors.white, size: 40),
                  onPressed: () => widget.api.next(),
                ),
                const SizedBox(width: 8),
                // Repeat
                IconButton(
                  icon: Icon(
                    Icons.repeat_rounded,
                    color: _playlist.isRepeat
                        ? const Color(0xFF18D1B5)
                        : Colors.white38,
                    size: 24,
                  ),
                  onPressed: () => widget.api.toggleRepeat(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Volume ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_down_rounded, size: 22),
                    color: Colors.white54,
                    onPressed: () => widget.api.volDown(),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5),
                        activeTrackColor: const Color(0xFF18D1B5),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFF18D1B5),
                      ),
                      child: Slider(
                        value: _playlist.volume.clamp(0.0, 1.0),
                        onChanged: (_) {},
                        onChangeEnd: (_) {},
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, size: 22),
                    color: Colors.white54,
                    onPressed: () => widget.api.volUp(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Global audio handler instance set from main.dart
RemoteAudioHandler? audioHandlerGlobal;
