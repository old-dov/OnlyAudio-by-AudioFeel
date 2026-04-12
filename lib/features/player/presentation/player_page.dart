import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/storage_service.dart';
import '../../library/data/library_service.dart';
import '../../remote/data/remote_api_server.dart';
import '../data/audio_service.dart';
import '../data/metadata_service.dart';
import '../logic/player_controller.dart';

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
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _controller.init();
    _searchController.text = _controller.searchQuery;
    await _remoteApi.start();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _playlistScrollController.dispose();
    _remoteApi.stop();
    _controller.disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _FocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              _searchController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _searchController.text.length,
              );
              return null;
            },
          ),
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('OnlyAudio by AudioFeel'),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        _controller.ready ? 'Remote API: :5000' : 'Loading...',
                      ),
                    ),
                  ),
                ],
              ),
              body: Row(
                children: [
                  SizedBox(width: 360, child: _buildPlaylistPanel()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildNowPlayingPanel()),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 250, child: _buildControlsPanel()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaylistPanel() {
    final visible = _controller.visibleIndices;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => _controller.addFiles(),
                child: const Text('+ FILES'),
              ),
              FilledButton(
                onPressed: () => _controller.addFolder(),
                child: const Text('+ FOLDER'),
              ),
              FilledButton.tonal(
                onPressed: () => _controller.removeCurrent(),
                child: const Text('REMOVE'),
              ),
              FilledButton.tonal(
                onPressed: () => _controller.clearPlaylist(),
                child: const Text('CLEAR'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Search tracks, folders, artist...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _controller.setSearchQuery,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _controller.cycleSortMode(),
                child: Text('SORT: ${_controller.sortMode.toUpperCase()}'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF111722),
              ),
              child: visible.isEmpty
                  ? const Center(child: Text('No results'))
                  : ListView.builder(
                      controller: _playlistScrollController,
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final realIndex = visible[i];
                        final track = _controller.playlist[realIndex];
                        final selected = realIndex == _controller.currentIndex;
                        return ListTile(
                          selected: selected,
                          selectedTileColor: const Color(0xFF1B3347),
                          dense: true,
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            p.basename(p.dirname(track.path)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _controller.playAt(realIndex),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlayingPanel() {
    final track = _controller.currentTrack;
    final cover = track?.coverBase64 ?? '';
    final coverBytes = cover.isNotEmpty ? base64Decode(cover) : null;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track?.title ?? 'No track selected',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(track?.artist ?? 'Unknown Artist',
              style: const TextStyle(color: Color(0xFF31A9FF), fontSize: 20)),
          const SizedBox(height: 4),
          Text(track?.album ?? 'Unknown Album',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF161D29),
                  image: coverBytes == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(coverBytes),
                          fit: BoxFit.cover,
                        ),
                ),
                child: coverBytes == null
                    ? const Icon(Icons.library_music_rounded, size: 120)
                    : null,
              ),
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(_formatDuration(_controller.currentPosition)),
              ),
              Expanded(
                child: Slider(
                  value: min(
                    _controller.currentPosition.inMilliseconds.toDouble(),
                    max(1, _controller.currentDuration.inMilliseconds)
                        .toDouble(),
                  ),
                  max: max(1, _controller.currentDuration.inMilliseconds)
                      .toDouble(),
                  onChanged: (v) =>
                      _controller.seek(Duration(milliseconds: v.toInt())),
                ),
              ),
              SizedBox(
                width: 58,
                child: Text(_formatDuration(_controller.currentDuration)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonal(
            onPressed: () => _controller.prev(),
            child: const Text('|< PREV'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _controller.playPause(),
            child: Text(_controller.isPaused ? 'PLAY' : 'PAUSE'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => _controller.next(),
            child: const Text('NEXT >|'),
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => _controller.toggleShuffle(),
            style: FilledButton.styleFrom(
              backgroundColor:
                  _controller.isShuffled ? const Color(0xFF0D6F59) : null,
            ),
            child: const Text('SHUFFLE'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => _controller.toggleRepeat(),
            style: FilledButton.styleFrom(
              backgroundColor:
                  _controller.isRepeat ? const Color(0xFF0D6F59) : null,
            ),
            child: const Text('REPEAT'),
          ),
          const SizedBox(height: 20),
          const Text('VOLUME', textAlign: TextAlign.center),
          Slider(
            value: _controller.volume,
            onChanged: _controller.setVolume,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _scrollToCurrent,
            child: const Text('JUMP TO NOW PLAYING'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ctrl+F for quick search',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _scrollToCurrent() {
    final visible = _controller.visibleIndices;
    final idx = visible.indexOf(_controller.currentIndex);
    if (idx < 0) {
      _searchController.clear();
      _controller.setSearchQuery('');
      return;
    }
    _playlistScrollController.animateTo(
      idx * 64.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
