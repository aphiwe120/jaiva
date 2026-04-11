import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/song_options_sheet.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Recently Played', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<Box<Song>>(
              valueListenable: Hive.box<Song>('history').listenable(),
              builder: (context, box, _) {
                // Reverse it so the most recently played song is at the top!
                final historySongs = box.values.toList().reversed.toList();

                if (historySongs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No listening history yet.\nGo play some tunes!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120, top: 8),
                  itemCount: historySongs.length,
                  itemBuilder: (context, index) {
                    final song = historySongs[index];
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
                          SongOptionsSheet.show(context, song);
                        },
                      ),
                      onTap: () {
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