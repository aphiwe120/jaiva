import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/screens/now_playing.dart'; 

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        
        // 1. The Magic Hide: If nothing is playing, the player completely vanishes
        if (mediaItem == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            // 2. Tapping the Mini-Player slides up the full Now Playing screen!
            // Note: If you named your class something else, update NowPlayingScreen() below
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NowPlayingScreen(),
                fullscreenDialog: true, // This makes it slide up from the bottom like Spotify
              ),
            );
          },
          child: Container(
            height: 64, // Standard Spotify mini-player height
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A), // Dark grey, pops slightly off the black background
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // --- ALBUM ART ---
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: mediaItem.artUri?.toString() ?? '',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(color: Colors.grey[800], child: const Icon(Icons.music_note, color: Colors.white)),
                          ),
                        ),
                      ),
                      
                      // --- TITLE & ARTIST ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              mediaItem.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis, // Adds the "..." if the title is too long
                            ),
                            Text(
                              mediaItem.artist ?? 'Unknown',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // --- PLAY / PAUSE BUTTON ---
                      StreamBuilder<PlaybackState>(
                        stream: audioHandler.playbackState,
                        builder: (context, stateSnapshot) {
                          final playing = stateSnapshot.data?.playing ?? false;
                          return IconButton(
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                            onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                          );
                        }
                      ),
                    ],
                  ),
                ),
                
                // --- THE PROGRESS BAR ---
                // This gives it that ultra-premium feel by tracking the song time at the very bottom edge
                StreamBuilder<Duration>(
                  stream: AudioService.position,
                  builder: (context, posSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final duration = mediaItem.duration ?? const Duration(milliseconds: 1);
                    
                    double progress = position.inMilliseconds / duration.inMilliseconds;
                    if (progress > 1.0) progress = 1.0;
                    if (progress < 0.0 || progress.isNaN) progress = 0.0;
                    
                    return ClipRRect(
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 2, // Very thin, just like Spotify
                      ),
                    );
                  }
                )
              ],
            ),
          ),
        );
      }
    );
  }
}