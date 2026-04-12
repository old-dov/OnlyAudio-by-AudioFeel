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
      ..get('/status', (Request request) {
        return Response.ok(
          jsonEncode(controller.remoteStatusPayload()),
          headers: {'content-type': 'application/json'},
        );
      })
      ..get('/play_pause', (Request request) async {
        await controller.playPause();
        return Response.ok('OK');
      })
      ..get('/prev', (Request request) async {
        await controller.prev();
        return Response.ok('OK');
      })
      ..get('/next', (Request request) async {
        await controller.next();
        return Response.ok('OK');
      })
      ..get('/vol_up', (Request request) async {
        await controller.setVolume((controller.volume + 0.1).clamp(0, 1));
        return Response.ok('OK');
      })
      ..get('/vol_down', (Request request) async {
        await controller.setVolume((controller.volume - 0.1).clamp(0, 1));
        return Response.ok('OK');
      })
      ..get('/shuffle', (Request request) async {
        await controller.toggleShuffle();
        return Response.ok('OK');
      })
      ..get('/repeat', (Request request) async {
        await controller.toggleRepeat();
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
