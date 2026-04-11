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

  // 🚨 Add tag here for proper MediaItem linking
  ByteAudioSource(this.bytes, {this.contentType = 'audio/mp4', dynamic tag}) : super(tag: tag);

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
  // 🚨 NEW: The Gapless Playlist Manager
  // 👻🎧 The Ghost DJ (Pre-loader + Smart Shuffle)
  Future<void> _precacheNextSong() async {
    // 1. CHECK THE QUEUE
    if (_currentIndex + 1 >= _dynamicQueue.length) {
      // 🚨 NEW: SMART SHUFFLE ENGINE (10-TRACK BATCH UPGRADE)
      if (isSmartShuffleEnabled && _dynamicQueue.isNotEmpty) {
        print('✨ [Ghost DJ] Queue is empty! Searching for a 10-track vibe...');
        try {
          final currentTrack = _dynamicQueue[_currentIndex];
          
          final currentVideo = await _youtubeExplode.videos.get(currentTrack.id).timeout(const Duration(seconds: 5));
          var relatedVideos = await _youtubeExplode.videos.getRelatedVideos(currentVideo).timeout(const Duration(seconds: 5));
          
          List<dynamic> nextVideosToQueue = [];

          if (relatedVideos != null && relatedVideos.isNotEmpty) {
            // Plan A: Find up to 10 short related videos
            nextVideosToQueue = relatedVideos
                .where((vid) => vid.duration != null && vid.duration!.inMinutes < 10)
                .take(10) // 👈 THIS IS THE MAGIC NUMBER! Grabs up to 10 songs.
                .toList();
                
            if (nextVideosToQueue.isEmpty) {
               nextVideosToQueue = relatedVideos.take(10).toList(); // Fallback
            }
          } else {
            // Plan B (The Fallback): Search artist name
            print('⚠️ [Ghost DJ] YouTube hid related videos. Searching for more by ${currentTrack.artist}...');
            final fallbackSearch = await _youtubeExplode.search.search('${currentTrack.artist} audio').timeout(const Duration(seconds: 5));
            
            if (fallbackSearch.isNotEmpty) {
              nextVideosToQueue = fallbackSearch
                  .where((vid) => vid.id.value != currentTrack.id)
                  .take(10) // 👈 Grabs up to 10 songs here too
                  .toList();
            }
          }

          // 2. Loop through our batch and add them all to the UI
          if (nextVideosToQueue.isNotEmpty) {
            for (var nextVideo in nextVideosToQueue) {
              final autoAddedSong = MediaItem(
                id: nextVideo.id.value,
                title: nextVideo.title,
                artist: nextVideo.author,
                duration: nextVideo.duration,
                artUri: Uri.parse(nextVideo.thumbnails.highResUrl), 
              );
              _dynamicQueue.add(autoAddedSong);
            }

            // 🚨 Update the UI Queue ONCE after all 10 are added
            queue.add(List.from(_dynamicQueue)); 
            
            print('✨ [Ghost DJ] Added ${nextVideosToQueue.length} new tracks to the queue!');
            // Code continues downwards so the Ghost Downloader saves ONLY the 1st one...
          } else {
             print('⚠️ [Ghost DJ] Plan A and Plan B failed. Going to sleep.');
             return;
          }

        } catch (e) {
          print('⚠️ [Ghost DJ] DJ completely crashed or timed out: $e');
          return;
        }
      } else {
        return; // Smart Shuffle is off, and queue is empty. Ghost sleeps.
      }
    }

    // 2. THE DOWNLOADER (Your exact same logic from before)
    final nextItem = _dynamicQueue[_currentIndex + 1];
    final dir = await getApplicationDocumentsDirectory();
    final localFile = File('${dir.path}/${nextItem.id}.mp4');

    if (await localFile.exists()) return; // Already downloaded!

    print('👻 [Ghost Downloader] Silently downloading next song: ${nextItem.title}');

    try {
      final manifest = await _youtubeExplode.videos.streamsClient.getManifest(
        nextItem.id,
        ytClients: [YoutubeApiClient.safari, YoutubeApiClient.androidVr],
      );
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      final stream = _youtubeExplode.videos.streamsClient.get(audioStreamInfo);
      
      final fileStream = localFile.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      print('✅ [Ghost Downloader] Next song is ready for INSTANT playback!');
    } catch (e) {
      print('❌ [Ghost Downloader] Failed to pre-load: $e');
    }
  }
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
  useLazyPreparation: true,
  children: [],
  );

  // ✨ NEW: Smart Shuffle Toggle
  bool isSmartShuffleEnabled = true;

  BackgroundAudioHandler(this._repository) {
    _init();
  }

  Future<void> _init() async {
    try {
      // 🚨 NEW: Tell the Janitor to check the storage space
      _cleanCacheIfTooBig();

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await _player.setAudioSource(_playlist);

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
        print('🎧 [AudioHandler] Ghost file found! Playing instantly with 0 data.');
        
        // 🚨 1. Wrap the local file in an AudioSource with the TAG
        // This is required so your notification bar shows the correct song title!
        final audioSource = AudioSource.uri(
          Uri.file(localFile.path),
          tag: item, 
        );
        
        // 🚨 2. Add it to our new Gapless Playlist engine instead of overwriting
        await _playlist.clear();
        await _playlist.add(audioSource);
        
        _player.play();
        print('▶️  [AudioHandler] Instant playback started!');
        
        // 🚨 3. The Recursion: Now that THIS song is playing, tell the Ghost 
        // to go look for the NEXT song!
        _precacheNextSong(); 
        
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
      
      // 🚨 NEW: THE CATCH-ALL SAVER
      // Save these bytes to a permanent file so next time it plays offline!
      try {
        final cacheFile = File('${dir.path}/${item.id}.mp4');
        await cacheFile.writeAsBytes(audioBytes);
        print('💾 [Cache] Saved streamed song to device for future offline use!');
      } catch (e) {
        print('⚠️ [Cache] Failed to save stream: $e');
      }
      
      print('▶️  [AudioHandler] Passing raw bytes to just_audio...');
      
      // 🚨 NEW: Clear and add to playlist with proper tagging
      await _playlist.clear();
      await _playlist.add(ByteAudioSource(
        audioBytes,
        contentType: audioStreamInfo.container.name == 'webm' ? 'audio/webm' : 'audio/mp4',
        tag: item, // 👈 Links the song info to the UI!
      ));

      _player.play();
      print('▶️  [AudioHandler] Playback started!');

      // 🚨 NEW: Tell the ghost to start preparing the next song
      _precacheNextSong();

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
    // 1. Add the song to the UI queue
    if (!_dynamicQueue.any((q) => q.id == item.id)) {
      _dynamicQueue.add(item);
      queue.add(_dynamicQueue);

      // 👻 🚨 NEW: WAKE UP THE GHOST!
      // Check if this newly added song is the VERY NEXT song in line.
      // (_dynamicQueue.length - 2 means the song we just added is right after the current one)
      if (_currentIndex == _dynamicQueue.length - 2) {
        print('👻 [Ghost Downloader] Waking up! User added a new next song.');
        _precacheNextSong();
      }
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

  // 🧹 The Cache Janitor
  Future<void> _cleanCacheIfTooBig() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      
      // Get all mp4 files in our folder
      final files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp4'))
          .toList();

      // Set a limit! 100 songs is roughly 300MB-400MB.
      if (files.length > 100) {
        print('🧹 [Cache Janitor] Storage limit reached. Cleaning up...');
        
        // Sort files by the oldest last-modified date
        files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        
        // Delete the 20 oldest songs to free up space
        for (int i = 0; i < 20; i++) {
          await files[i].delete();
        }
        print('✅ [Cache Janitor] Deleted 20 old songs. Storage optimized!');
      }
    } catch (e) {
      print('⚠️ [Cache Janitor] Failed to clean cache: $e');
    }
  }

  void dispose() {
    print('🧹 [AudioHandler] Disposing resources...');
    _youtubeExplode.close();
    _player.dispose();
    print('✅ [AudioHandler] Resources disposed');
  }
}