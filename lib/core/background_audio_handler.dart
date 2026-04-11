import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:jaiva/core/music_repository.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive/hive.dart';
import 'package:jaiva/models/song.dart';
import 'package:path_provider/path_provider.dart';

/// Custom audio source that feeds raw bytes to just_audio
/// This bypasses ExoPlayer's HTTP requests, avoiding YouTube 403 blocks
class ByteAudioSource extends StreamAudioSource {
  final List<int> bytes;
  final String contentType;

  ByteAudioSource(this.bytes, {this.contentType = 'audio/mp4'});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: contentType,
    );
  }
}

class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final MusicRepository _repository;
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  
  final List<MediaItem> _dynamicQueue = [];
  int _currentIndex = -1;

  BackgroundAudioHandler(this._repository) {
    _init();
  }

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _player.playbackEventStream.listen((PlaybackEvent event) {
        final playing = _player.playing;
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
          ],
          // 🚨 1. THIS IS THE MAGIC FLAG! It tells Android/iOS to show the draggable scrubber
          systemActions: const {
            MediaAction.seek, 
          },
          // 🚨 2. You must feed it the current position so the OS knows where to draw the dot
          updatePosition: _player.position, 
          playing: playing,
          processingState: AudioProcessingState.ready,
        ));
        
        if (_player.processingState == ProcessingState.completed) {
           skipToNext();
        }
      });

      // 🚨 Add duration tracking for the progress bar
      _player.durationStream.listen((duration) {
        final currentItem = mediaItem.value;
        if (currentItem != null && duration != null) {
          // Replace the old MediaItem with a new one that has the correct duration
          mediaItem.add(currentItem.copyWith(duration: duration));
        }
      });
    } catch (e) {
      print('ERROR: $e');
    }
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    if (!_dynamicQueue.any((q) => q.id == item.id)) {
      _dynamicQueue.add(item);
    }
    _currentIndex = _dynamicQueue.indexWhere((q) => q.id == item.id);
    mediaItem.add(item);
    queue.add(_dynamicQueue);

    // 🔴 HIVE HISTORY: Save to playback history 🔴
    try {
      final historyBox = Hive.box<Song>('history');
      
      // Convert MediaItem to our custom Song object
      final playedSong = Song(
        id: item.id,
        title: item.title,
        artist: item.artist ?? 'Unknown Artist',
        thumbnailUrl: item.artUri?.toString() ?? '',
      );

      // If the song is already in history, delete it so we can move it to the top
      final existingKey = historyBox.keys.firstWhere(
        (k) => historyBox.get(k)?.id == playedSong.id, 
        orElse: () => null,
      );
      if (existingKey != null) {
        await historyBox.delete(existingKey);
      }

      // Add to the end (Hive keeps order)
      await historyBox.add(playedSong);

      // Keep the box clean: Only store the last 50 songs
      if (historyBox.length > 50) {
        await historyBox.deleteAt(0); // Delete the oldest
      }
    } catch (e) {
      print('⚠️  [Hive] Failed to save history: $e');
    }
    // 🔴 END HIVE LOGIC 🔴

    try {
      // 1. CHECK FOR OFFLINE FILE FIRST
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/${item.id}.mp4');

      if (await localFile.exists()) {
        print('🎧 [AudioHandler] Found local file! Playing OFFLINE without data!');
        
        // Feed the local file directly to just_audio
        await _player.setAudioSource(AudioSource.uri(Uri.file(localFile.path)));
        _player.play();
        print('▶️  [AudioHandler] Offline Playback started!');
        return; // EXIT EARLY - NO INTERNET NEEDED!
      }

      // 2. IF NOT OFFLINE, DO THE NORMAL RAM STREAM
      print('🔄 [AudioHandler] No local file. Streaming from internet...');
      
      // Use special YouTube clients to bypass 403 blocks
      final manifest = await _youtubeExplode.videos.streamsClient.getManifest(
        item.id,
        ytClients: [YoutubeApiClient.safari, YoutubeApiClient.androidVr],
      );
      
      // Get the highest quality audio
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      
      print('🔄 [AudioHandler] Downloading stream to memory (bypassing ExoPlayer)...');
      
      // Get the actual byte stream instead of just the URL
      final stream = _youtubeExplode.videos.streamsClient.get(audioStreamInfo);
      
      // Collect the bytes into memory
      List<int> audioBytes = [];
      await for (final chunk in stream) {
        audioBytes.addAll(chunk);
      }

      print('✅ [AudioHandler] Stream downloaded! (${(audioBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
      print('▶️  [AudioHandler] Passing raw bytes to just_audio...');
      
      // Feed the bytes to just_audio using our custom ByteAudioSource
      await _player.setAudioSource(
        ByteAudioSource(
          audioBytes,
          contentType: audioStreamInfo.container.name == 'webm' ? 'audio/webm' : 'audio/mp4',
        ),
      );

      _player.play();
      print('▶️  [AudioHandler] Playback started!');

    } catch (e) {
      print('❌ [AudioHandler] Extraction or Playback failed: $e');
    }
  }

  @override Future<void> play() => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> seek(Duration position) => _player.seek(position);
  
  @override
  Future<void> skipToNext() async {
    if (_currentIndex + 1 < _dynamicQueue.length) {
      await playMediaItem(_dynamicQueue[_currentIndex + 1]);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      seek(Duration.zero);
    } else if (_currentIndex > 0) {
      await playMediaItem(_dynamicQueue[_currentIndex - 1]);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    // Adds a song to the end of the queue
    if (!_dynamicQueue.any((q) => q.id == item.id)) {
      _dynamicQueue.add(item);
      queue.add(_dynamicQueue);
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem item) async {
    // Removes a song from the queue
    _dynamicQueue.removeWhere((q) => q.id == item.id);
    queue.add(_dynamicQueue);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    // Allows drag-and-drop reordering in the UI
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _dynamicQueue.removeAt(oldIndex);
    _dynamicQueue.insert(newIndex, item);
    
    // Update the current index so we don't accidentally skip songs
    final currentItem = mediaItem.value;
    if (currentItem != null) {
      _currentIndex = _dynamicQueue.indexWhere((q) => q.id == currentItem.id);
    }
    queue.add(_dynamicQueue);
  }

  void dispose() {
    print('🧹 [AudioHandler] Disposing resources...');
    _youtubeExplode.close();
    _player.dispose();
    print('✅ [AudioHandler] Resources disposed');
  }
}