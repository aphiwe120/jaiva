import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/core/search_provider.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/jaiva_bottom_nav.dart';
import 'package:jaiva/ui/screens/history_screen.dart';
import 'package:jaiva/ui/screens/settings_screen.dart';

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
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 🚨 FIX: Wrapped the scrolling area in Positioned.fill to prevent the crash!
          Positioned.fill(
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  // --- HEADER ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_none, color: Colors.white), 
                                onPressed: () {
                                  // We can leave this one dead for now, or add a snackbar!
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No new notifications')));
                                }
                              ),
                              IconButton(
                                icon: const Icon(Icons.history, color: Colors.white), 
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()));
                                }
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings_outlined, color: Colors.white), 
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                                }
                              ),
                            ],
                          )
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
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text('Recently Played', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ),
                            SizedBox(
                              height: 160,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: historySongs.length,
                                itemBuilder: (context, index) {
                                  final song = historySongs[index];
                                  return GestureDetector(
                                    onTap: () {
                                      ref.read(audioHandlerProvider).playMediaItem(MediaItem(
                                        id: song.id, title: song.title, artist: song.artist, artUri: Uri.parse(song.thumbnailUrl),
                                      ));
                                    },
                                    child: Container(
                                      width: 110,
                                      margin: const EdgeInsets.only(right: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: song.thumbnailUrl, height: 110, width: 110, fit: BoxFit.cover,
                                              errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: const Icon(Icons.music_note, color: Colors.white)),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                        ],
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
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text("Trending in South Africa", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ref.watch(trendingProvider).when(
                        data: (trendingSongs) {
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: trendingSongs.length,
                            itemBuilder: (context, index) {
                              final song = trendingSongs[index];
                              return GestureDetector(
                                onTap: () {
                                  ref.read(audioHandlerProvider).playMediaItem(MediaItem(
                                    id: song.id, title: song.title, artist: song.artist, artUri: Uri.parse(song.thumbnailUrl),
                                  ));
                                },
                                child: Container(
                                  width: 140,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(imageUrl: song.thumbnailUrl, width: 140, height: 140, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
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