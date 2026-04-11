import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/song_options_sheet.dart';

class LikedSongsScreen extends ConsumerWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Liked Songs', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // 🚨 Wrapped in Positioned.fill to prevent the Red Screen of Death!
          Positioned.fill(
            child: ValueListenableBuilder<Box<Song>>(
              // Directly listening to the 'likes' box!
              valueListenable: Hive.box<Song>('likes').listenable(),
              builder: (context, box, _) {
                final likedSongs = box.values.toList().reversed.toList(); // Newest likes at the top

                if (likedSongs.isEmpty) {
                  return const Center(
                    child: Text(
                      "You haven't liked any songs yet.\nTap the heart icon on a track!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    // --- THE FANCY HEADER ---
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.deepPurple.withOpacity(0.8),
                              const Color(0xFF121212),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.deepPurple, Colors.white70],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
                                ],
                              ),
                              child: const Icon(Icons.favorite, color: Colors.white, size: 50),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Liked Songs", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text("${likedSongs.length} songs", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- THE SONGS LIST ---
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = likedSongs[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl: song.thumbnailUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), maxLines: 1),
                              subtitle: Text(song.artist, style: const TextStyle(color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                                onPressed: () {
                                  // Open your master options sheet!
                                  SongOptionsSheet.show(context, song);
                                },
                              ),
                              onTap: () {
                                // Play the song!
                                ref.read(audioHandlerProvider).playMediaItem(MediaItem(
                                  id: song.id,
                                  title: song.title,
                                  artist: song.artist,
                                  artUri: Uri.parse(song.thumbnailUrl),
                                ));
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