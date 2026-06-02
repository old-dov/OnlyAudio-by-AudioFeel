import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../player/logic/player_controller.dart';

class RemoteApiServer {
  RemoteApiServer(this.controller);

  final PlayerController controller;
  HttpServer? _server;

  Future<void> start({int port = 5000}) async {
    if (_server != null) return;
    final router = Router()
      ..get('/discover', (Request request) {
        return Response.ok(
          jsonEncode({'app': 'OnlyAudio'}),
          headers: {'content-type': 'application/json'},
        );
      })
      ..get('/status', (Request request) async {
        return Response.ok(
          jsonEncode(await controller.remoteStatusPayload()),
          headers: {'content-type': 'application/json'},
        );
      })
      ..get('/playlist', (Request request) {
        return Response.ok(
          jsonEncode(controller.remotePlaylistPayload()),
          headers: {'content-type': 'application/json'},
        );
      })
      ..get('/seek/<posMs>', (Request request, String posMs) async {
        final ms = int.tryParse(posMs) ?? 0;
        await controller.seek(Duration(milliseconds: ms));
        return Response.ok('OK');
      })
      ..get('/play_index/<idx>', (Request request, String idx) async {
        final i = int.tryParse(idx) ?? 0;
        await controller.playAt(i);
        return Response.ok('OK');
      })
      ..get('/play_pause', (Request request) {
        unawaited(controller.playPause());
        return Response.ok('OK');
      })
      ..get('/prev', (Request request) {
        unawaited(controller.prev());
        return Response.ok('OK');
      })
      ..get('/next', (Request request) {
        unawaited(controller.next());
        return Response.ok('OK');
      })
      ..get('/vol_up', (Request request) {
        unawaited(controller.setVolume((controller.volume + 0.1).clamp(0, 1)));
        return Response.ok('OK');
      })
      ..get('/vol_down', (Request request) {
        unawaited(controller.setVolume((controller.volume - 0.1).clamp(0, 1)));
        return Response.ok('OK');
      })
      ..get('/shuffle', (Request request) {
        unawaited(controller.toggleShuffle());
        return Response.ok('OK');
      })
      ..get('/repeat', (Request request) {
        unawaited(controller.toggleRepeat());
        return Response.ok('OK');
      });

    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
