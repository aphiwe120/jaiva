import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:jaiva/core/music_repository.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive/hive.dart';
import 'package:jaiva/models/song.dart';
import 'package:path_provider/path_provider.dart';

class ByteAudioSource extends StreamAudioSource {
  final List<int> bytes;
  final String contentType;

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
  // 1. CLASS VARIABLES
  final AudioPlayer _player = AudioPlayer();
  final MusicRepository _repository;
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  final List<MediaItem> _dynamicQueue = [];
  int _currentIndex = -1;
  bool _isDownloading = false;
  bool _isSearching = false; // 🚨 NEW: Protect Smart Shuffle search phase
  bool isSmartShuffleEnabled = true;
  DateTime _lastAutoSkip = DateTime.fromMillisecondsSinceEpoch(0); // 🚨 NEW: Prevent auto-skip spam

  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: [],
  );

  // 2. CONSTRUCTOR
  BackgroundAudioHandler(this._repository) {
    _init();
  }

  // 3. INITIALIZATION
  Future<void> _init() async {
    try {
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
          systemActions: const {MediaAction.seek},
          updatePosition: _player.position,
          playing: playing,
          processingState: AudioProcessingState.ready,
        ));
        
        if (_player.processingState == ProcessingState.completed) {
          // 🚨 NEW: 20-SECOND LOOP BREAKER
          final now = DateTime.now();
          if (now.difference(_lastAutoSkip).inSeconds < 20) { // 👈 CHANGED TO 20
            print('🛑 [LOOP BREAKER] Hardware crash detected. Halting auto-skip to save data!');
            _player.pause(); // Force the player to stop
            return;
          }
          
          _lastAutoSkip = now;
          skipToNext();
        }
      });

      _player.durationStream.listen((duration) {
        final currentItem = mediaItem.value;
        if (currentItem != null && duration != null) {
          mediaItem.add(currentItem.copyWith(duration: duration));
        }
      });
    } catch (e) {
      print('ERROR INIT: $e');
    }
  }

  // 4. CORE PLAYBACK LOGIC
  @override
  Future<void> playMediaItem(MediaItem item) async {
    if (!_dynamicQueue.any((q) => q.id == item.id)) {
      _dynamicQueue.add(item);
    }
    _currentIndex = _dynamicQueue.indexWhere((q) => q.id == item.id);
    
    // Trigger DJ if we are playing the very last song in the queue
    if (_currentIndex == _dynamicQueue.length - 1) {
      print('⚠️ [AudioHandler] Playing last song. Triggering Smart Shuffle early!');
      _precacheNextSong();
    }
    
    mediaItem.add(item);
    queue.add(List.from(_dynamicQueue));

    // Save History to Hive
    try {
      final historyBox = Hive.box<Song>('history');
      final playedSong = Song(id: item.id, title: item.title, artist: item.artist ?? 'Unknown Artist', thumbnailUrl: item.artUri?.toString() ?? '');
      final existingKey = historyBox.keys.firstWhere((k) => historyBox.get(k)?.id == playedSong.id, orElse: () => null);
      if (existingKey != null) await historyBox.delete(existingKey);
      await historyBox.add(playedSong);
      if (historyBox.length > 50) await historyBox.deleteAt(0);
    } catch (e) { print('⚠️ Hive Error: $e'); }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/${item.id}.mp4');

      // Play Cached File
      if (await localFile.exists() && await localFile.length() > 50000) {
        print('🎧 [AudioHandler] Playing cached file.');
        final audioSource = AudioSource.uri(Uri.file(localFile.path), tag: item);
        await _playlist.clear();
        await _playlist.add(audioSource);
        _player.play();
        _precacheNextSong(); 
        return;
      }

      // Stream from YouTube
      print('🔄 [AudioHandler] Streaming...');
      final manifest = await _youtubeExplode.videos.streamsClient.getManifest(item.id, ytClients: [YoutubeApiClient.safari, YoutubeApiClient.androidVr]);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      final stream = _youtubeExplode.videos.streamsClient.get(audioStreamInfo);
      
      List<int> audioBytes = [];
      await for (final chunk in stream) { audioBytes.addAll(chunk); }

      // Save to Cache
      final cacheFile = File('${dir.path}/${item.id}.mp4');
      await cacheFile.writeAsBytes(audioBytes);

      await _playlist.clear();
      await _playlist.add(ByteAudioSource(audioBytes, contentType: audioStreamInfo.container.name == 'webm' ? 'audio/webm' : 'audio/mp4', tag: item));
      _player.play();
      _precacheNextSong();
    } catch (e) {
      print('❌ Playback failed: $e');
      Future.delayed(const Duration(seconds: 2), () => skipToNext());
    }
  }

  // 5. GHOST DJ & SMART SHUFFLE
  Future<void> _precacheNextSong() async {
    print('🔎 [Diagnostic] Ghost DJ check: Index=$_currentIndex, QueueSize=${_dynamicQueue.length}');

    // 🚨 NEW: Lock the search phase to prevent race conditions!
    if (isSmartShuffleEnabled && _dynamicQueue.length <= _currentIndex + 2) {
      if (_isSearching) {
        print('⏳ [Ghost DJ] Already searching. Ignoring duplicate trigger.');
        return;
      }
      _isSearching = true;
      
      try {
        print('✨ [Ghost DJ] Queue is running low. Fetching a new batch...');
        
        final seedTrack = _dynamicQueue.isNotEmpty ? _dynamicQueue.last : null;
        if (seedTrack == null) return;

        // 🚨 ADDED TIMEOUTS BACK: Prevent the app from freezing if YouTube ignores us!
        final video = await _youtubeExplode.videos.get(seedTrack.id).timeout(const Duration(seconds: 5));
        
        List<dynamic> batch = [];

        try {
          // PLAN A: Related Videos
          var related = await _youtubeExplode.videos.getRelatedVideos(video).timeout(const Duration(seconds: 5));
          if (related != null && related.isNotEmpty) {
            // 🚨 THE MORNING FIX: STRICTLY AUDIO BOUNCER
            batch = related.where((vid) {
              final title = vid.title.toLowerCase();
              
              // 1. Must be normal song length
              final isRightLength = vid.duration != null && vid.duration!.inMinutes < 10;
              
              // 2. Ban all videos with skits or visualizers
              final isCleanAudio = !title.contains('music video') && 
                                   !title.contains('official video') && 
                                   !title.contains('visualizer') &&
                                   !title.contains('live');
                                   
              return isRightLength && isCleanAudio;
            }).take(10).toList();
          }
        } catch (e) {
          print('⚠️ [Ghost DJ] YouTube blocked Plan A. Switching to Plan B...');
        }

        // 🚨 PLAN B: If Plan A failed or returned nothing, search the artist instead!
        if (batch.isEmpty) {
          final fallbackSearch = await _youtubeExplode.search.search('${seedTrack.artist} audio').timeout(const Duration(seconds: 5));
          // 🚨 APPLY THE SAME FILTER TO FALLBACK SEARCH!
          batch = fallbackSearch.where((vid) {
            final title = vid.title.toLowerCase();
            
            // 1. Must be normal song length
            final isRightLength = vid.duration != null && vid.duration!.inMinutes < 10;
            
            // 2. Ban all videos with skits or visualizers
            final isCleanAudio = !title.contains('music video') && 
                                 !title.contains('official video') && 
                                 !title.contains('visualizer') &&
                                 !title.contains('live');
                                 
            return isRightLength && isCleanAudio && vid.id.value != seedTrack.id;
          }).take(10).toList();
        }
        
        // 🚨 UPDATE UI
        if (batch.isNotEmpty) {
          for (var vid in batch) {
            _dynamicQueue.add(MediaItem(
              id: vid.id.value, 
              title: vid.title, 
              artist: vid.author, 
              duration: vid.duration, 
              artUri: Uri.parse(vid.thumbnails.highResUrl)
            ));
          }
          queue.add(List.from(_dynamicQueue));
          print('✨ [Ghost DJ] SUCCESS! Added ${batch.length} tracks to the queue.');
        } else {
          print('❌ [Ghost DJ] Both Plan A and B failed. DJ is taking a break.');
        }
      } catch (e) {
        print('⚠️ [Ghost DJ] Complete System Failure: $e');
      } finally {
        _isSearching = false; // Always unlock
      }
    }

    // DOWNLOAD PHASE (Lock protected)
    if (_isDownloading) return;
    if (_currentIndex + 1 < _dynamicQueue.length) {
      final nextItem = _dynamicQueue[_currentIndex + 1];
      final dir = await getApplicationDocumentsDirectory();
      
      final finalFile = File('${dir.path}/${nextItem.id}.mp4');
      final tempFile = File('${dir.path}/${nextItem.id}.temp'); // 🚨 NEW: The safe zone

      if (await finalFile.exists() && await finalFile.length() > 50000) return;

      _isDownloading = true; 
      try {
        print('👻 [Ghost Downloader] Fetching: ${nextItem.title}');
        final manifest = await _youtubeExplode.videos.streamsClient.getManifest(
          nextItem.id, 
          ytClients: [YoutubeApiClient.safari, YoutubeApiClient.androidVr]
        );
        final stream = _youtubeExplode.videos.streamsClient.get(manifest.audioOnly.withHighestBitrate());
        
        // 🚨 WRITE TO TEMP FILE FIRST
        final fileStream = tempFile.openWrite();
        await stream.pipe(fileStream);
        await fileStream.flush();
        await fileStream.close();
        
        // 🚨 RENAME ONLY WHEN 100% FINISHED
        await tempFile.rename(finalFile.path);
        print('✅ [Ghost Downloader] Success. File safely locked and ready.');
        
      } catch (e) {
        print('❌ [Ghost Downloader] Error. Skipping cache for this track.');
        if (await tempFile.exists()) await tempFile.delete(); // Clean up temp file
      } finally {
        _isDownloading = false; 
      }
    }
  }

  // 6. HELPER METHODS
  Future<void> _cleanCacheIfTooBig() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.mp4')).toList();
      if (files.length > 100) {
        files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        for (int i = 0; i < 20; i++) { await files[i].delete(); }
      }
    } catch (e) { print('Janitor Error: $e'); }
  }

  @override Future<void> play() => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> seek(Duration position) => _player.seek(position);
  @override Future<void> stop() => _player.stop();

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
  Future<void> addQueueItem(MediaItem item) async {
    if (!_dynamicQueue.any((q) => q.id == item.id)) {
      _dynamicQueue.add(item);
      queue.add(List.from(_dynamicQueue));
      if (_currentIndex == _dynamicQueue.length - 2) _precacheNextSong();
    }
  }

  void dispose() {
    _youtubeExplode.close();
    _player.dispose();
  }
}