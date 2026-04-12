import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_state.dart';
import '../models/track.dart';

class StorageService {
  static const _playlistKey = 'playlist_v1';
  static const _stateKey = 'player_state_v1';

  Future<void> savePlaylist(List<Track> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = tracks.map((t) => t.toJson()).toList();
    await prefs.setString(_playlistKey, jsonEncode(payload));
  }

  Future<List<Track>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playlistKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<void> saveState(PlayerStateModel state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, jsonEncode(state.toJson()));
  }

  Future<PlayerStateModel> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) {
      return PlayerStateModel();
    }
    return PlayerStateModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
