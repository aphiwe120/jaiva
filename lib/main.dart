import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // REQUIRED FOR RIVERPOD
import 'package:hive_flutter/hive_flutter.dart';         // REQUIRED FOR MOBILE HIVE
import 'package:audio_service/audio_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jaiva/ui/screens/lock_screen.dart'; // We will build this next!
import 'package:jaiva/models/song.dart';
import 'package:jaiva/models/playlist.dart';
import 'package:jaiva/core/background_audio_handler.dart';
import 'package:jaiva/core/music_repository.dart';
import 'package:jaiva/core/player_provider.dart'; // Assuming you have your audioHandlerProvider here
import 'package:jaiva/ui/screens/home_screen.dart'; // REQUIRED FOR THE HOME SCREEN

BackgroundAudioHandler? _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive (Your existing code)
  await Hive.initFlutter();
  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(PlaylistAdapter());
  await Hive.openBox<Song>('likes');
  await Hive.openBox<Song>('history');
  await Hive.openBox<Playlist>('playlists');
  await Hive.openBox<Song>('downloads');

  // 2. 🚨 INITIALIZE SUPABASE
  await Supabase.initialize(
    url: 'https://iwabmausbitaphmqyfwg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3YWJtYXVzYml0YXBobXF5ZndnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MDE5MDcsImV4cCI6MjA5MTQ3NzkwN30.9rjhb-lF8SCY5OILkl3XOMR-IL-XI7-rIdSceIvFukQ', // <-- Grab this from your Supabase dashboard!
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
    );
  } catch (e) {
    debugPrint('❌ Error initializing AudioService: $e');
  }

  // 4. Check if they already logged in previously!
  final prefs = await SharedPreferences.getInstance();
  final savedCode = prefs.getString('vip_code');

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(_audioHandler!),
      ],
      // 5. 🚨 ROUTING LOGIC: If they have a saved code, go home. If not, hit the bouncer.
      child: MyApp(initialRoute: savedCode != null ? '/home' : '/lock'),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jaiva',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      // 🚨 The routing logic
      initialRoute: initialRoute,
      routes: {
        '/lock': (context) => const LockScreen(),
        '/home': (context) => const HomeScreen(), // Your existing home screen
      },
    );
  }
}