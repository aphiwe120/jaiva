import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/models/playlist.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/song_options_sheet.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // 🚨 Wrapped in Positioned.fill to prevent the Red Screen of Death!
          Positioned.fill(
            child: ValueListenableBuilder<Box<Playlist>>(
              // We listen to the Hive box so if you add a song, this screen updates instantly!
              valueListenable: Hive.box<Playlist>('playlists').listenable(),
              builder: (context, box, _) {
                // Find our specific playlist to get the most up-to-date songs
                final currentPlaylist = box.values.firstWhere(
                  (p) => p.id == playlist.id,
                  orElse: () => playlist,
                );

                final songs = currentPlaylist.songs;

                if (songs.isEmpty) {
                  return const Center(
                    child: Text(
                      "This playlist is empty.\nGo find some music!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120, top: 16),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
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