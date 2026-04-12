import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({
    super.key,
    required this.api,
    required this.playlist,
  });

  final ApiClient api;
  final RemotePlaylist playlist;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late RemotePlaylist _playlist;
  final _searchController = TextEditingController();
  Timer? _refreshTimer;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    try {
      final pl = await widget.api.fetchPlaylist();
      if (!mounted) return;
      setState(() => _playlist = pl);
    } catch (_) {}
  }

  List<RemoteTrack> get _filteredTracks {
    if (_query.isEmpty) return _playlist.tracks;
    final q = _query.toLowerCase();
    return _playlist.tracks
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.folder.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTracks;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Playlist (${_playlist.tracks.length})'),
        backgroundColor: const Color(0xFF0B0E13),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher dans la liste...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFF141922),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // Track list
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun résultat',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final track = filtered[i];
                      final isCurrent =
                          track.index == _playlist.currentIndex;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isCurrent
                              ? const Color(0xFF1B3347)
                              : Colors.transparent,
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          leading: isCurrent
                              ? const Icon(Icons.play_arrow_rounded,
                                  color: Color(0xFF31A9FF), size: 22)
                              : Text(
                                  '${track.index + 1}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 13),
                                ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isCurrent
                                  ? const Color(0xFF31A9FF)
                                  : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            track.folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                          onTap: () {
                            widget.api.playIndex(track.index);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
