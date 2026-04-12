import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/connection_screen.dart';
import 'screens/remote_player_screen.dart';
import 'services/remote_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Launch the app immediately — don't block on audio_service init
  runApp(const OnlyAudioRemoteApp());

  // Init audio_service in the background (non-blocking)
  try {
    audioHandlerGlobal = await AudioService.init(
      builder: () => RemoteAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.audiofeel.onlyaudio_remote.channel',
        androidNotificationChannelName: 'OnlyAudio Remote',
        androidNotificationOngoing: false,
        androidShowNotificationBadge: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('AudioService init failed (non-critical): $e');
    // App works fine without notification bar
  }
}

class OnlyAudioRemoteApp extends StatelessWidget {
  const OnlyAudioRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnlyAudio Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E13),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF31A9FF),
          secondary: Color(0xFF18D1B5),
          surface: Color(0xFF141922),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0E13),
          elevation: 0,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF31A9FF),
          thumbColor: Color(0xFF31A9FF),
        ),
        useMaterial3: true,
      ),
      home: const ConnectionScreen(),
    );
  }
}
