import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/song_options_sheet.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';
import 'package:jaiva/ui/widgets/kinetic_song_tile.dart';

class LikedSongsScreen extends ConsumerWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Liked Songs',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 🎨 Kinetic Vault: Aura Orb Background
          const AuraOrb(
            auraValue: 0.8, // Cyan for liked/favorites
            size: 400.0,
          ),

          // 🚨 Wrapped in Positioned.fill to prevent the Red Screen of Death!
          Positioned.fill(
            child: ValueListenableBuilder<Box<Song>>(
              // Directly listening to the 'likes' box!
              valueListenable: Hive.box<Song>('likes').listenable(),
              builder: (context, box, _) {
                final likedSongs = box.values.toList().reversed.toList(); // Newest likes at the top

                if (likedSongs.isEmpty) {
                  return Center(
                    child: Text(
                      "You haven't liked any songs yet.\nTap the heart icon on a track!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    // --- THE KINETIC VAULT HEADER ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            // 💖 Heart Icon Container
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEC4899),
                                    Color(0xFF7C3AED),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEC4899).withOpacity(0.5),
                                    blurRadius: 20.0,
                                    spreadRadius: 5.0,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.favorite, color: Colors.white, size: 50),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Liked Songs",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "${likedSongs.length} songs",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- THE SONGS MASONRY GRID ---
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0).copyWith(bottom: 140),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12.0,
                          crossAxisSpacing: 12.0,
                          childAspectRatio: 0.85,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = likedSongs[index];
                            return KineticSongTile(
                              song: song,
                              bpm: 120.0,
                              genre: 'Liked',
                              onTap: () {
                                ref.read(audioHandlerProvider).playMediaItem(MediaItem(
                                  id: song.id,
                                  title: song.title,
                                  artist: song.artist,
                                  artUri: Uri.parse(song.thumbnailUrl),
                                ));
                              },
                              onLongPress: () {
                                SongOptionsSheet.show(context, song);
                              },
                            );
                          },
                          childCount: likedSongs.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
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
    );
  }
}