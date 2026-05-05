import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/services/storage_service.dart';
import '../../library/data/library_service.dart';
import '../../remote/data/remote_api_server.dart';
import '../data/audio_service.dart';
import '../data/metadata_service.dart';
import '../logic/player_controller.dart';

// ── couleurs ─────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF000000);
const _kCyan   = Color(0xFF00C8FF);
const _kGreen  = Color(0xFF009900);
const _kOrange = Color(0xFF8B4500);
const _kRed    = Color(0xFF6B1515);
const _kBarGreen  = Color(0xFF00C000);
const _kBarYellow = Color(0xFFCCCC00);
const _kBarOrange = Color(0xFFCC7000);

// ── bouton style Kivy (rectangulaire, bords arrondis) ─────────────────────────
Widget _darkBtn(
  String label,
  VoidCallback? onPressed, {
  Color bg = const Color(0xFF1E1E1E),
  Color fg = Colors.white,
  double fontSize = 11.5,
  double height = 30,
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
        child: Text(label,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: onPressed == null ? fg.withValues(alpha: 0.35) : fg,
                letterSpacing: 0.5)),
      ),
    ),
  );
}

// ── spectrum analyzer painter ─────────────────────────────────────────────────
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
  static const _n = 48;
  final _bars = List<double>.filled(_n, 0);
  final _phases = List<double>.generate(
      _n, (_) => Random().nextDouble() * pi * 2);
  final _speeds = List<double>.generate(
      _n, (_) => 2.0 + Random().nextDouble() * 4.0);
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

// ── main page ───────────────────────────────────────────────────────────────
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerController _controller;
  late final RemoteApiServer _remoteApi;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _playlistScrollController = ScrollController();
  int _focusedVisibleIndex = -1;
  int _lastCurrentIndex = -1;
  double? _seekingValue; // valeur locale pendant le drag du slider
  bool _isFullScreen = false;
  Uint8List? _cachedCoverBytes;
  String? _cachedCoverTrackPath;

  @override
  void initState() {
    super.initState();
    _controller = PlayerController(
      audioService: AudioService(),
      metadataService: MetadataService(),
      storageService: StorageService(),
      libraryService: LibraryService(),
    );
    _remoteApi = RemoteApiServer(_controller);
    _controller.addListener(_onTrackChanged);
    _bootstrap();
  }

  void _onTrackChanged() {
    final idx = _controller.currentIndex;
    _updateCoverCache();
    if (idx == _lastCurrentIndex) return;
    _lastCurrentIndex = idx;
    final visible = _controller.visibleIndices;
    final visIdx = visible.indexOf(idx);
    if (visIdx < 0) return;
    setState(() => _focusedVisibleIndex = visIdx);
    SchedulerBinding.instance.addPostFrameCallback(
      (_) { if (mounted) _scrollToFocused(); },
    );
  }

  void _updateCoverCache() {
    final track = _controller.currentTrack;
    final path = track?.path;
    if (path == _cachedCoverTrackPath) return;
    _cachedCoverTrackPath = path;
    final cover = track?.coverBase64 ?? '';
    _cachedCoverBytes = cover.isNotEmpty ? base64Decode(cover) : null;
  }

  Future<void> _bootstrap() async {
    await _controller.init();
    _updateCoverCache();
    _searchController.text = _controller.searchQuery;
    try {
      await _remoteApi.start();
    } catch (e) {
      // ignore: avoid_print
      print('[RemoteApi] failed to start: $e');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTrackChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _playlistScrollController.dispose();
    _remoteApi.stop();
    _controller.disposeController();
    super.dispose();
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _FocusSearchIntent(),
      },
      child: Actions(
        actions: {
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              _searchController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _searchController.text.length);
              return null;
            },
          ),
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _buildScaffold(context),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // 1. pochette ou image par défaut en fond plein écran
          _buildBackground(),
          // 2. voile sombre pour lisibilité
          Positioned.fill(
            child: Container(color: const Color(0x66000000)),
          ),
          // 3. contenu
          Column(
            children: [
              _buildHeader(),
              const Expanded(child: SizedBox()),
              _buildBottomBar(),
            ],
          ),
        ],
      ),
    );
  }

  // ── background (pochette grand format ou image par défaut) ─────────────────
  Widget _buildBackground() {
    final coverBytes = _cachedCoverBytes;
    return Positioned.fill(
      child: coverBytes != null
          ? Image.memory(
              coverBytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              color: const Color(0x77000000),
              colorBlendMode: BlendMode.darken,
            )
          : Image.asset(
              'assets/bg_default.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
              color: const Color(0x99000000),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => Container(color: _kBg),
            ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 36,
      color: const Color(0xDD141414),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Text('OnlyAudio',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          const SizedBox(width: 16),
          // Plein écran
          InkWell(
            onTap: () async {
              _isFullScreen = !_isFullScreen;
              await windowManager.setFullScreen(_isFullScreen);
              setState(() {});
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white60,
                size: 16,
              ),
            ),
          ),
          InkWell(
            onTap: () => exit(0),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('X',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── barre du bas ──────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xEA080808),
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 320, child: _buildPlaylistPanel()),
          Container(width: 1, color: const Color(0xFF252525)),
          Expanded(child: _buildCenterPanel()),
          Container(width: 1, color: const Color(0xFF252525)),
          SizedBox(width: 200, child: _buildControlsPanel()),
        ],
      ),
    );
  }

  // ── panel playlist ────────────────────────────────────────────────────────
  Widget _buildPlaylistPanel() {
    final visible = _controller.visibleIndices;
    return Column(
      children: [
        // ligne 1 : +FICHIER | +DOSSIER | -TITRE
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 3),
          child: Row(
            children: [
              Expanded(
                  child: _darkBtn('+FICHIER', () => _controller.addFiles(),
                      fg: _kCyan)),
              const SizedBox(width: 4),
              Expanded(
                  child: _darkBtn('+DOSSIER', () => _controller.addFolder(),
                      fg: _kCyan)),
              const SizedBox(width: 4),
              Expanded(
                  child: _darkBtn('-TITRE', () => _controller.removeCurrent(),
                      bg: _kRed)),
            ],
          ),
        ),
        // ligne 2 : OUVRIR PL | SAUVER PL | VIDER
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
          child: Row(
            children: [
              Expanded(
                  child: _darkBtn('OUVRIR PL', null, fg: Colors.white38)),
              const SizedBox(width: 4),
              Expanded(
                  child: _darkBtn('SAUVER PL', null, fg: Colors.white38)),
              const SizedBox(width: 4),
              Expanded(
                  child: _darkBtn(
                      'VIDER', () => _controller.clearPlaylist())),
            ],
          ),
        ),
        // recherche + tri
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: Colors.white30),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _controller.setSearchQuery,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _darkBtn(
                'TRI: ${_controller.sortMode.toUpperCase()}',
                () => _controller.cycleSortMode(),
                fg: Colors.white60,
                fontSize: 10,
              ),
            ],
          ),
        ),
        // liste
        Expanded(
          child: Container(
            color: const Color(0xFF060606),
            child: visible.isEmpty
                ? const Center(
                    child: Text('Aucun résultat',
                        style: TextStyle(
                            color: Colors.white30, fontSize: 12)))
                : Focus(
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent &&
                          event is! KeyRepeatEvent) {
                        return KeyEventResult.ignored;
                      }
                      if (event.logicalKey ==
                          LogicalKeyboardKey.arrowDown) {
                        setState(() {
                          _focusedVisibleIndex =
                              (_focusedVisibleIndex + 1)
                                  .clamp(0, visible.length - 1);
                        });
                        _scrollToFocused();
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.arrowUp) {
                        setState(() {
                          _focusedVisibleIndex =
                              (_focusedVisibleIndex - 1)
                                  .clamp(0, visible.length - 1);
                        });
                        _scrollToFocused();
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.enter) {
                        if (_focusedVisibleIndex >= 0 &&
                            _focusedVisibleIndex < visible.length) {
                          _controller
                              .playAt(visible[_focusedVisibleIndex]);
                        }
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: ListView.builder(
                      controller: _playlistScrollController,
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final realIndex = visible[i];
                        final track = _controller.playlist[realIndex];
                        final isPlaying =
                            realIndex == _controller.currentIndex;
                        final isFocused = i == _focusedVisibleIndex;
                        return InkWell(
                          onTap: () {
                            setState(() => _focusedVisibleIndex = i);
                            _controller.playAt(realIndex);
                          },
                          child: Container(
                            height: 28,
                            color: isPlaying
                                ? const Color(0xFF002233)
                                : isFocused
                                    ? const Color(0xFF161622)
                                    : Colors.transparent,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    '${i + 1}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: isPlaying
                                          ? _kCyan
                                          : Colors.white30,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isPlaying
                                          ? _kCyan
                                          : Colors.white70,
                                      fontWeight: isPlaying
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── panel central (cover vignette + info + VU + progress) ─────────────────
  Widget _buildCenterPanel() {
    final track = _controller.currentTrack;
    final coverBytes = _cachedCoverBytes;
    final posSec =
        _controller.currentPosition.inMilliseconds / 1000.0;
    final durMs =
        max(1, _controller.currentDuration.inMilliseconds).toDouble();
    final posMs = min(
        _controller.currentPosition.inMilliseconds.toDouble(), durMs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(
        children: [
          // vignette + titre/artiste/album
          Row(
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
                          fit: BoxFit.cover),
                ),
                child: coverBytes == null
                    ? const Icon(Icons.library_music,
                        size: 38, color: Colors.white24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track?.title ?? 'Aucun titre',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track?.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: _kCyan,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track?.album ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTrackMeta(track),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // vu-mètre
          Expanded(
            child: _SpectrumWidget(
              isPlaying: !_controller.isPaused,
              positionSec: posSec,
            ),
          ),
          const SizedBox(height: 6),
          // barre de progression
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  _formatDuration(_controller.currentPosition),
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: Colors.white70,
                    inactiveTrackColor: const Color(0xFF444444),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: (_seekingValue ?? posMs).clamp(0.0, durMs),
                    max: durMs,
                    onChangeStart: (v) => setState(() => _seekingValue = v),
                    onChanged: (v) => setState(() => _seekingValue = v),
                    onChangeEnd: (v) {
                      _controller.seek(Duration(milliseconds: v.toInt()));
                      setState(() => _seekingValue = null);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  _formatDuration(_controller.currentDuration),
                  textAlign: TextAlign.right,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── panel contrôles ───────────────────────────────────────────────────────
  Widget _buildControlsPanel() {
    final isPlaying = !_controller.isPaused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // |<   PAUSE/PLAY   >|
          Row(
            children: [
              SizedBox(
                width: 38,
                child: _darkBtn('|<', () => _controller.prev(),
                    height: 38, fontSize: 15),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _darkBtn(
                  isPlaying ? 'PAUSE' : 'PLAY',
                  () => _controller.playPause(),
                  bg: const Color(0xFF6B3A00),
                  height: 38,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 38,
                child: _darkBtn('>|', () => _controller.next(),
                    height: 38, fontSize: 15),
              ),
            ],
          ),
          // ALEA | BOUCLE | EQ
          Row(
            children: [
              Expanded(
                child: _darkBtn(
                  'ALEA',
                  () => _controller.toggleShuffle(),
                  bg: _controller.isShuffled
                      ? _kGreen
                      : const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _darkBtn(
                  'BOUCLE',
                  () => _controller.toggleRepeat(),
                  bg: _controller.isRepeat
                      ? _kGreen
                      : const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _darkBtn('EQ', null,
                    bg: const Color(0xFF2A2000), fg: Colors.white38),
              ),
            ],
          ),
          // -  VOL slider  +
          Row(
            children: [
              _darkBtn(
                '-',
                () => _controller.setVolume(
                    (_controller.volume - 0.05).clamp(0.0, 1.0)),
                fontSize: 16,
                height: 30,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: _kCyan,
                    inactiveTrackColor: const Color(0xFF333333),
                    thumbColor: _kCyan,
                    overlayColor: _kCyan.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _controller.volume,
                    onChanged: _controller.setVolume,
                  ),
                ),
              ),
              _darkBtn(
                '+',
                () => _controller.setVolume(
                    (_controller.volume + 0.05).clamp(0.0, 1.0)),
                bg: _kOrange,
                fontSize: 16,
                height: 30,
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ── helpers ───────────────────────────────────────────────────────────────
  void _scrollToFocused() {
    if (_focusedVisibleIndex < 0) return;
    _playlistScrollController.animateTo(
      _focusedVisibleIndex * 28.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  String _formatTrackMeta(dynamic track) {
    if (track == null) return '';
    final parts = <String>[];
    if (track.year != null && track.year! > 0) parts.add('${track.year}');
    final ms = track.durationMs as int;
    if (ms > 0) parts.add(_formatDuration(Duration(milliseconds: ms)));
    return parts.join(' · ');
  }

  String _formatDuration(Duration value) {
    final m = value.inMinutes;
    final s = value.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}
