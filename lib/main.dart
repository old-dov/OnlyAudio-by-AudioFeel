import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app/only_audio_app.dart';

ServerSocket? _singleInstanceGuard;

Future<bool> _acquireSingleInstanceGuard() async {
  try {
    _singleInstanceGuard = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      43157,
      shared: false,
    );
    assert(_singleInstanceGuard != null);
    return true;
  } on SocketException {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!await _acquireSingleInstanceGuard()) {
    debugPrint('OnlyAudio is already running. Exiting duplicate instance.');
    return;
  }
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'OnlyAudio by AudioFeel',
      minimumSize: Size(700, 480),
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  runApp(const OnlyAudioApp());
}
