import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/core/player_provider.dart';

class PlaybackProgressBar extends ConsumerWidget {
  const PlaybackProgressBar({super.key});

  // Helper to format Duration into mm:ss
  String _formatDuration(Duration? duration) {
    if (duration == null) return "0:00";
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final mediaItem = mediaSnapshot.data;
        final duration = mediaItem?.duration ?? Duration.zero;

        // AudioService.position streams the exact current millisecond of the song
        return StreamBuilder<Duration>(
          stream: AudioService.position,
          builder: (context, positionSnapshot) {
            var position = positionSnapshot.data ?? Duration.zero;

            // Safety check: Prevent slider crash if position overshoots duration momentarily
            if (position > duration && duration != Duration.zero) {
              position = duration;
            }

            final maxDuration = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
            final currentPosition = position.inMilliseconds.toDouble().clamp(0.0, maxDuration);

            return Column(
              children: [
                // --- THE SLIDER ---
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withOpacity(0.2),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: maxDuration,
                    value: currentPosition,
                    onChanged: (value) {
                      // Tell AudioService to skip to the exact millisecond the user dragged to!
                      audioHandler.seek(Duration(milliseconds: value.round()));
                    },
                  ),
                ),
                
                // --- THE TIMESTAMPS ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}