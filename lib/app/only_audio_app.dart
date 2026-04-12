import 'package:flutter/material.dart';

import '../features/player/presentation/player_page.dart';

class OnlyAudioApp extends StatelessWidget {
  const OnlyAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnlyAudio by AudioFeel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E13),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF31A9FF),
          secondary: Color(0xFF18D1B5),
          surface: Color(0xFF141922),
        ),
        useMaterial3: true,
      ),
      home: const PlayerPage(),
    );
  }
}
