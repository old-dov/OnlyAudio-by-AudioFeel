import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/api_client.dart';
import '../services/remote_audio_handler.dart';
import 'connection_screen.dart';
import 'playlist_screen.dart';

// ── couleurs (identiques au lecteur principal) ────────────────────────────────
const _kBg        = Color(0xFF000000);
const _kCyan      = Color(0xFF00C8FF);
const _kGreen     = Color(0xFF009900);
const _kOrange    = Color(0xFF8B4500);
const _kBarGreen  = Color(0xFF00C000);
const _kBarYellow = Color(0xFFCCCC00);
const _kBarOrange = Color(0xFFCC7000);

// ── bouton style lecteur ──────────────────────────────────────────────────────
Widget _darkBtn(
  String label,
  VoidCallback? onPressed, {
  Color bg = const Color(0xFF1E1E1E),
  Color fg = Colors.white,
  double fontSize = 13,
  double height = 42,
}) {
  return SizedBox(
    height: height,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg,
        disabledForegroundColor: fg.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        elevation: 0,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: onPressed == null ? fg.withValues(alpha: 0.35) : fg,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ),
  );
}

// ── analyseur de spectre (animé, identique au lecteur) ───────────────────────
class _SpectrumPainter extends CustomPainter {
  final List<double> bars;
  _SpectrumPainter(this.bars);

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final n = bars.length;
    final barW = (size.width - (n - 1) * gap) / n;
    for (var i = 0; i < n; i++) {
      final ratio = i / max(1, n - 1);
      final color = ratio < 0.65
          ? _kBarGreen
          : ratio < 0.85
              ? _kBarYellow
              : _kBarOrange;
      final h = bars[i] * size.height;
      final x = i * (barW + gap);
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, barW, h),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) => true;
}

class _SpectrumWidget extends StatefulWidget {
  final bool isPlaying;
  final double positionSec;
  const _SpectrumWidget({required this.isPlaying, required this.positionSec});

  @override
  State<_SpectrumWidget> createState() => _SpectrumWidgetState();
}

class _SpectrumWidgetState extends State<_SpectrumWidget>
    with SingleTickerProviderStateMixin {
  static const _n = 36;
  final _bars = List<double>.filled(_n, 0);
  final _phases =
      List<double>.generate(_n, (_) => Random().nextDouble() * pi * 2);
  final _speeds =
      List<double>.generate(_n, (_) => 2.0 + Random().nextDouble() * 4.0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration _) {
    final t = widget.positionSec;
    if (widget.isPlaying) {
      for (var i = 0; i < _n; i++) {
        var base = 0.4 + 0.3 * sin(t * _speeds[i] + _phases[i]);
        base += 0.2 * sin(t * _speeds[i] * 1.7 + _phases[i] * 0.6);
        final target =
            (base + (Random().nextDouble() - 0.5) * 0.2).clamp(0.0, 1.0);
        _bars[i] += (target - _bars[i]) * 0.45;
      }
    } else {
      for (var i = 0; i < _n; i++) {
        _bars[i] *= 0.88;
        if (_bars[i] < 0.01) _bars[i] = 0;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SpectrumPainter(List.unmodifiable(_bars)),
        child: const SizedBox.expand(),
      );
}

// ── écran principal ───────────────────────────────────────────────────────────
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
      _audioHandler?.setPlaying(status.isPlaying);
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

  void _disconnect() {
    _pollTimer?.cancel();
    _audioHandler?.stop();
    widget.api.dispose();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectionScreen()),
    );
  }

  String _formatMs(int ms) {
    if (ms <= 0) return '0:00';
    final m = ms ~/ 60000;
    final s = (ms ~/ 1000) % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatCountdown(int posMs, int durMs) {
    final remaining = (durMs - posMs).clamp(0, durMs);
    return '-${_formatMs(remaining)}';
  }

  String _formatTrackMeta() {
    final parts = <String>[];
    final y = _status.year;
    if (y != null && y > 0) parts.add('$y');
    if (_status.durMs > 0) parts.add(_formatMs(_status.durMs));
    return parts.join(' · ');
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
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateCoverCache();
    final coverBytes = _cachedCoverBytes;
    final isPlaying = _status.isPlaying;
    final posMs = _seeking ? _seekValue.toInt() : _status.posMs;
    final durMs = _status.durMs;
    final posSec = posMs / 1000.0;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── fond : pochette plein écran assombrie ──
          Positioned.fill(
            child: coverBytes != null
                ? Image.memory(
                    coverBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    color: const Color(0x88000000),
                    colorBlendMode: BlendMode.darken,
                  )
                : Container(color: _kBg),
          ),
          // ── voile sombre supplémentaire ──
          Positioned.fill(
            child: Container(color: const Color(0x55000000)),
          ),
          // ── contenu ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        _buildTrackInfo(coverBytes),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: _SpectrumWidget(
                            isPlaying: isPlaying,
                            positionSec: posSec,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSeekBar(posMs, durMs),
                        const SizedBox(height: 16),
                        _buildMainControls(isPlaying),
                        const SizedBox(height: 10),
                        _buildSecondaryControls(),
                        const SizedBox(height: 10),
                        _buildVolumeRow(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── en-tête ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 44,
      color: const Color(0xDD141414),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(
            _connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: _connected ? _kCyan : Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'OnlyAudio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.playlist_play_rounded, size: 26),
            color: Colors.white70,
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
            icon: const Icon(Icons.link_off_rounded, size: 20),
            color: Colors.white54,
            tooltip: 'Déconnecter',
            onPressed: _disconnect,
          ),
        ],
      ),
    );
  }

  // ── vignette + infos ──────────────────────────────────────────────────────
  Widget _buildTrackInfo(Uint8List? coverBytes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(4),
            image: coverBytes == null
                ? null
                : DecorationImage(
                    image: MemoryImage(coverBytes),
                    fit: BoxFit.cover,
                  ),
          ),
          child: coverBytes == null
              ? const Icon(Icons.library_music, size: 38, color: Colors.white24)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _status.title.isNotEmpty ? _status.title : 'Aucun titre',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _status.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: _kCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _status.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTrackMeta(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── barre de progression + décompte ──────────────────────────────────────
  Widget _buildSeekBar(int posMs, int durMs) {
    final maxVal = max(1, durMs).toDouble();
    final curVal = (_seeking ? _seekValue : posMs.toDouble()).clamp(0.0, maxVal);
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: Colors.white70,
            inactiveTrackColor: const Color(0xFF444444),
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: curVal,
            max: maxVal,
            onChangeStart: (v) {
              _seeking = true;
              _seekValue = v;
            },
            onChanged: (v) => setState(() => _seekValue = v),
            onChangeEnd: (v) {
              _seeking = false;
              widget.api.seek(v.toInt());
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMs(posMs),
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
              // décompte centré en grand
              Text(
                _formatCountdown(posMs, durMs),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── contrôles principaux : |<  PAUSE/PLAY  >| ────────────────────────────
  Widget _buildMainControls(bool isPlaying) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: _darkBtn('|<', () => widget.api.prev(), height: 52, fontSize: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _darkBtn(
            isPlaying ? 'PAUSE' : 'PLAY',
            () => widget.api.playPause(),
            bg: _kOrange,
            height: 52,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: _darkBtn('>|', () => widget.api.next(), height: 52, fontSize: 18),
        ),
      ],
    );
  }

  // ── contrôles secondaires : ALÉA | BOUCLE | PLAYLIST ─────────────────────
  Widget _buildSecondaryControls() {
    return Row(
      children: [
        Expanded(
          child: _darkBtn(
            'ALÉA',
            () => widget.api.toggleShuffle(),
            bg: _playlist.isShuffled ? _kGreen : const Color(0xFF1E1E1E),
            height: 36,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _darkBtn(
            'BOUCLE',
            () => widget.api.toggleRepeat(),
            bg: _playlist.isRepeat ? _kGreen : const Color(0xFF1E1E1E),
            height: 36,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _darkBtn(
            'PLAYLIST',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaylistScreen(
                  api: widget.api,
                  playlist: _playlist,
                ),
              ),
            ),
            height: 36,
            fg: Colors.white70,
          ),
        ),
      ],
    );
  }

  // ── volume : -  slider  + ─────────────────────────────────────────────────
  Widget _buildVolumeRow() {
    return Row(
      children: [
        _darkBtn('-', () => widget.api.volDown(), fontSize: 18, height: 36),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: _kCyan,
              inactiveTrackColor: const Color(0xFF333333),
              thumbColor: _kCyan,
              overlayColor: _kCyan.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _playlist.volume.clamp(0.0, 1.0),
              onChanged: (_) {},
              onChangeEnd: (_) {},
            ),
          ),
        ),
        _darkBtn('+', () => widget.api.volUp(),
            bg: _kOrange, fontSize: 18, height: 36),
      ],
    );
  }
}

/// Instance globale de l'audio handler, initialisée dans main.dart
RemoteAudioHandler? audioHandlerGlobal;
