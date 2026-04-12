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
        actions: [
          TextButton.icon(
            onPressed: () {
              // Show a quick confirmation dialog so they don't click it by mistake
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text('Clear Queue?', style: TextStyle(color: Colors.white)),
                  content: const Text('This will remove all upcoming songs.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        audioHandler.clearQueue();
                        Navigator.pop(context);
                      },
                      child: const Text('CLEAR', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent, size: 20),
            label: const Text('CLEAR', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<List<MediaItem>>(
        stream: audioHandler.queue,
        builder: (context, snapshot) {
          final queue = snapshot.data ?? [];

          if (queue.isEmpty) {
            return const Center(
              child: Text('Your queue is empty', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ReorderableListView.builder(
            itemCount: queue.length,
            // 🚨 Crucial: Every item needs a Unique Key for the drag-animation to work
            itemBuilder: (context, index) {
              final item = queue[index];
              return Dismissible(
                key: ValueKey('dismiss_${item.id}'), // Unique key for swipe-to-delete
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent.withOpacity(0.8),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => audioHandler.removeQueueItem(item),
                child: ListTile(
                  key: ValueKey(item.id), // 👈 Unique ID is mandatory!
                  leading: CachedNetworkImage(
                    imageUrl: item.artUri?.toString() ?? '',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note, color: Colors.white54),
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.artist ?? 'Unknown Artist',
                    style: const TextStyle(color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.drag_handle, color: Colors.white24),
                  onTap: () {
                    audioHandler.playMediaItem(item);
                    Navigator.pop(context); // Close queue after playing
                  },
                ),
              );
            },
            // 🚨 This sends the new position back to the engine
            onReorder: (oldIndex, newIndex) {
              audioHandler.moveQueueItem(oldIndex, newIndex);
            },
          );
        },
      ),
    );
  }
}