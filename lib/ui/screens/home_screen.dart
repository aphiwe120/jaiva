import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/core/search_provider.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/jaiva_bottom_nav.dart';
import 'package:jaiva/ui/screens/history_screen.dart';
import 'package:jaiva/ui/screens/settings_screen.dart';
import 'package:jaiva/ui/screens/vault_screen.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';
import 'package:jaiva/ui/widgets/kinetic_song_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // 🎨 Kinetic Vault: Aura Orb Background
          const AuraOrb(
            auraValue: 0.5,
            size: 400.0,
          ),

          // 🚨 FIX: Wrapped the scrolling area in Positioned.fill to prevent the crash!
          Positioned.fill(
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Row(
                        children: [
                          // 🚨 THE FIX: Wrap title in Expanded so it yields space to the buttons!
                          Expanded(
                            child: Text(
                              _getGreeting(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.history, color: Colors.white),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()));
                            }
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_special_rounded, color: Colors.white),
                            tooltip: 'Offline Vault',
                            onPressed: () {
                              final audioHandler = ref.read(audioHandlerProvider);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VaultScreen(audioHandler: audioHandler),
                                ),
                              );
                            }
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                            }
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- RECENTLY PLAYED (HIVE HISTORY) ---
                  ValueListenableBuilder<Box<Song>>(
                    valueListenable: Hive.box<Song>('history').listenable(),
                    builder: (context, box, _) {
                      if (box.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                      final historySongs = box.values.toList().reversed.take(10).toList();

                      return SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                              child: Text(
                                'Recently Played',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 180,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: historySongs.length,
                                itemBuilder: (context, index) {
                                  final song = historySongs[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: SizedBox(
                                      width: 140,
                                      child: KineticSongTile(
                                        song: song,
                                        bpm: 120.0, // Will be dynamic later
                                        genre: 'Amapiano',
                                        onTap: () {
                                          ref.read(audioHandlerProvider).playMediaItem(MediaItem(
                                            id: song.id,
                                            title: song.title,
                                            artist: song.artist,
                                            artUri: Uri.parse(song.thumbnailUrl),
                                          ));
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // --- TRENDING MASKANDI / AMAPIANO ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text(
                        "Trending in South Africa",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: ref.watch(trendingProvider).when(
                        data: (trendingSongs) {
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: trendingSongs.length,
                            itemBuilder: (context, index) {
                              final song = trendingSongs[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                  width: 160,
                                  child: KineticSongTile(
                                    song: song,
                                    bpm: 128.0, // Trending songs are typically upbeat
                                    genre: 'Amapiano',
                                    onTap: () {
                                      ref.read(audioHandlerProvider).playMediaItem(MediaItem(
                                        id: song.id,
                                        title: song.title,
                                        artist: song.artist,
                                        artUri: Uri.parse(song.thumbnailUrl),
                                      ));
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)), // MiniPlayer padding
                ],
              ),
            ),
          ),
          
          // --- MINI PLAYER ---
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: const JaivaBottomNav(currentIndex: 0),
    );
  }
}