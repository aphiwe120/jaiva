import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:audio_service/audio_service.dart';

class PlayerControlWidget extends ConsumerWidget {
  const PlayerControlWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerStateAsync = ref.watch(playerStateProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    return playerStateAsync.when(
      data: (state) {
        final isPlaying = state.playing;
        final isBuffering = state.processingState == AudioProcessingState.loading || 
                            state.processingState == AudioProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              iconSize: 48.0,
              onPressed: () => audioHandler.skipToPrevious(),
            ),
            if (isBuffering)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else if (isPlaying)
              IconButton(
                icon: const Icon(Icons.pause_circle_filled),
                iconSize: 64.0,
                color: Colors.white,
                onPressed: () => audioHandler.pause(),
              )
            else
              IconButton(
                icon: const Icon(Icons.play_circle_fill),
                iconSize: 64.0,
                onPressed: () => audioHandler.play(),
              ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              iconSize: 48.0,
              onPressed: () => audioHandler.skipToNext(),
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text('Error loading player: $e'),
    );
  }
}
