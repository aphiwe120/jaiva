import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/core/lyrics_provider.dart';

class SynchronizedLyrics extends ConsumerStatefulWidget {
  const SynchronizedLyrics({super.key});

  @override
  ConsumerState<SynchronizedLyrics> createState() => _SynchronizedLyricsState();
}

class _SynchronizedLyricsState extends ConsumerState<SynchronizedLyrics> {
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);

    // 1. Loading State
    if (lyricsState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }

    // 2. Error State
    if (lyricsState.error != null) {
      return Center(child: Text(lyricsState.error!, style: const TextStyle(color: Colors.white54)));
    }

    // 3. Synced Lyrics (The Holy Grail!)
    if (lyricsState.syncedLyrics != null) {
      final lyrics = lyricsState.syncedLyrics!;

      return StreamBuilder<Duration>(
        stream: AudioService.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;

          // Find the active lyric line based on the audio timestamp
          int currentIndex = -1;
          for (int i = 0; i < lyrics.length; i++) {
            if (position >= lyrics[i].timestamp) {
              currentIndex = i;
            } else {
              break; // Stop searching once we pass the current time
            }
          }

          // Auto-scroll to keep the active line in the center of the view!
          if (currentIndex != _lastIndex && currentIndex != -1) {
            _lastIndex = currentIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                // Rough math to center the text: ~40 pixels per line
                final offset = (currentIndex * 40.0) - (MediaQuery.of(context).size.height * 0.15);
                _scrollController.animateTo(
                  offset > 0 ? offset : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }

          return ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            // Add padding so you can scroll past the last line
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.4, top: 16),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final isActive = index == currentIndex;
              final line = lyrics[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white24, // Bright white if active, dim if not
                    fontSize: isActive ? 26 : 22, // Pop out slightly when active!
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  ),
                  child: Text(line.text),
                ),
              );
            },
          );
        },
      );
    }

    // 4. Plain text fallback (If the song has lyrics, but no timestamps)
    if (lyricsState.plainLyrics != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          lyricsState.plainLyrics!,
          style: const TextStyle(color: Colors.white54, fontSize: 18, height: 1.5),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}