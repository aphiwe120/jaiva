import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Note: We don't need shared_preferences or lock_screen.dart anymore!

import 'package:jaiva/ui/screens/auth/auth_gate.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/models/playlist.dart';
import 'package:jaiva/core/background_audio_handler.dart';
import 'package:jaiva/core/music_repository.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart'; 

BackgroundAudioHandler? _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(PlaylistAdapter());
  await Hive.openBox<Song>('likes');
  await Hive.openBox<Song>('history');
  await Hive.openBox<Playlist>('playlists');
  await Hive.openBox<Song>('downloads');
  await Hive.openBox<Song>('vault');
  await Hive.openBox('settings');
  await Hive.openBox('blacklist');

  // 2. 🚨 INITIALIZE SUPABASE
  await Supabase.initialize(
    url: 'https://iwabmausbitaphmqyfwg.supabase.co',
    anonKey:'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3YWJtYXVzYml0YXBobXF5ZndnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MDE5MDcsImV4cCI6MjA5MTQ3NzkwN30.9rjhb-lF8SCY5OILkl3XOMR-IL-XI7-rIdSceIvFukQ', // I hid it here for text brevity, but keep yours!
  );

  // 3. Initialize Music Repository and AudioService
  final musicRepo = MusicRepository();

  try {
    _audioHandler = await AudioService.init(
      builder: () => BackgroundAudioHandler(musicRepo),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.jaiva.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ),
    ) as BackgroundAudioHandler;
  } catch (e) {
    debugPrint('❌ Error initializing AudioService: $e');
  }

  // 4. 🚀 RUN APP (Notice how clean this is now!)
  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(_audioHandler!),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jaiva',
      debugShowCheckedModeBanner: false,
      theme: kineticVaultThemeData,
      //  NEW ROUTING LOGIC: We let the AuthGate decide what screen to show!
      home: const AuthGate(), 
    );
  }
}