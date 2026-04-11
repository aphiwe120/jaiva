import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jaiva/core/player_provider.dart';
// Note: You may need to cast your audioHandler to BackgroundAudioHandler to access reorderQueue
// Or handle reordering locally and call a custom method.

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Play Queue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<MediaItem>>(
        stream: audioHandler.queue,
        builder: (context, queueSnapshot) {
          return StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, mediaItemSnapshot) {
              final currentItem = mediaItemSnapshot.data;
              final fullQueue = queueSnapshot.data ?? [];
              
              if (fullQueue.isEmpty && currentItem == null) {
                return const Center(child: Text("Your queue is empty", style: TextStyle(color: Colors.grey)));
              }

              // Find where we are in the queue
              final currentIndex = fullQueue.indexWhere((item) => item.id == currentItem?.id);
              
              // Split the queue into "Now Playing" and "Next Up"
              final upcomingSongs = currentIndex != -1 && currentIndex + 1 < fullQueue.length 
                  ? fullQueue.sublist(currentIndex + 1) 
                  : <MediaItem>[];

              return CustomScrollView(
                slivers: [
                  // --- NOW PLAYING SECTION ---
                  if (currentItem != null) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text("Now Playing", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ListTile(
                        leading: CachedNetworkImage(
                          imageUrl: currentItem.artUri?.toString() ?? '',
                          width: 50, height: 50, fit: BoxFit.cover,
                        ),
                        title: Text(currentItem.title, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        subtitle: Text(currentItem.artist ?? 'Unknown', style: const TextStyle(color: Colors.green)),
                        trailing: const Icon(Icons.equalizer, color: Colors.green), // Playing animation icon
                      ),
                    ),
                  ],

                  // --- NEXT UP SECTION ---
                  if (upcomingSongs.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
                        child: Text("Next In Queue", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SliverReorderableList(
                      itemCount: upcomingSongs.length,
                      onReorder: (oldIndex, newIndex) {
                        // Offset by the currentIndex to adjust the actual master queue
                        // Note: If you want drag-and-drop, you will need to call the reorderQueue method we added.
                        // For a simple cast: (audioHandler as dynamic).reorderQueue(currentIndex + 1 + oldIndex, currentIndex + 1 + newIndex);
                      },
                      itemBuilder: (context, index) {
                        final song = upcomingSongs[index];
                        return ListTile(
                          key: ValueKey(song.id),
                          leading: CachedNetworkImage(
                            imageUrl: song.artUri?.toString() ?? '',
                            width: 50, height: 50, fit: BoxFit.cover,
                          ),
                          title: Text(song.title, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(song.artist ?? '', style: const TextStyle(color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                                onPressed: () => audioHandler.removeQueueItem(song), // Remove from queue
                              ),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                          onTap: () {
                            // Skip directly to this song
                            audioHandler.playMediaItem(song);
                          },
                        );
                      },
                    ),
                  ]
                ],
              );
            },
          );
        },
      ),
    );
  }
}