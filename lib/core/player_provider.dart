import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/core/background_audio_handler.dart';

final audioHandlerProvider = Provider<BackgroundAudioHandler>((ref) {
  throw UnimplementedError('Must be initialized and overridden in main.dart');
});

class PlayerState {
  final AudioProcessingState processingState;
  final bool playing;
  final Duration position;
  final Duration duration;

  PlayerState({
    required this.processingState,
    required this.playing,
    required this.position,
    required this.duration,
  });
}

// A stream provider that exposes combined playback state for the progress bar & UI logic
final playerStateProvider = StreamProvider<PlayerState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  
  return AudioService.position.map((position) {
    final state = handler.playbackState.value;
    final item = handler.mediaItem.value;
    
    return PlayerState(
      processingState: state.processingState,
      playing: state.playing,
      position: position,
      duration: item?.duration ?? Duration.zero,
    );
  });
});
