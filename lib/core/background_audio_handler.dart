import 'dart:async';
import 'dart:io'; // Ensures the cache manager can read files
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
  
  // 🚨 NEW: Hardware EQ initialized FIRST
  final AndroidEqualizer _equalizer = AndroidEqualizer(); 
  
  // 🚨 NEW: Player initialized SECOND, with the EQ plugged into its pipeline
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_equalizer],
    ),
  );
  
  final MusicRepository _repository;
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  final List<MediaItem> _dynamicQueue = [];
  int _currentIndex = -1;
  bool _isDownloading = false;
  bool _isSearching = false; 
  bool isSmartShuffleEnabled = true;
  DateTime _lastAutoSkip = DateTime.fromMillisecondsSinceEpoch(0); 

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
      
      // Keep mobile background sessions active
      if (Platform.isAndroid || Platform.isIOS) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      }
      
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
          final now = DateTime.now();
          if (now.difference(_lastAutoSkip).inSeconds < 20) { 
            print('🛑 [LOOP BREAKER] Hardware crash detected. Halting auto-skip to save data!');
            _player.pause(); 
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
    // 🚨 NEW V1.2 LOGIC: Wipe the old queue to start fresh with this selection
    _dynamicQueue.clear(); 
    _dynamicQueue.add(item);
    _currentIndex = 0;

    // Update the streams so the UI knows the queue is now just this one song
    mediaItem.add(item);
    queue.add(List.from(_dynamicQueue));

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

      if (await localFile.exists() && await localFile.length() > 50000) {
        print('🎧 [AudioHandler] Playing cached file.');
        final audioSource = AudioSource.uri(Uri.file(localFile.path), tag: item);
        await _playlist.clear();
        await _playlist.add(audioSource);
        _player.play();
        _precacheNextSong(); 
        return;
      }

      print('🔄 [AudioHandler] Streaming...');
      final manifest = await _youtubeExplode.videos.streamsClient.getManifest(item.id, ytClients: [YoutubeApiClient.safari, YoutubeApiClient.androidVr]);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      final stream = _youtubeExplode.videos.streamsClient.get(audioStreamInfo);
      
      List<int> audioBytes = [];
      await for (final chunk in stream) { audioBytes.addAll(chunk); }

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

        final video = await _youtubeExplode.videos.get(seedTrack.id).timeout(const Duration(seconds: 5));
        
        List<dynamic> batch = [];

        try {
          var related = await _youtubeExplode.videos.getRelatedVideos(video).timeout(const Duration(seconds: 5));
          if (related != null && related.isNotEmpty) {
            batch = related.where((vid) {
              final title = vid.title.toLowerCase();
              final isRightLength = vid.duration != null && vid.duration!.inMinutes < 10;
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

        if (batch.isEmpty) {
          final fallbackSearch = await _youtubeExplode.search.search('${seedTrack.artist} audio').timeout(const Duration(seconds: 5));
          batch = fallbackSearch.where((vid) {
            final title = vid.title.toLowerCase();
            final isRightLength = vid.duration != null && vid.duration!.inMinutes < 10;
            final isCleanAudio = !title.contains('music video') && 
                                 !title.contains('official video') && 
                                 !title.contains('visualizer') &&
                                 !title.contains('live');
            return isRightLength && isCleanAudio && vid.id.value != seedTrack.id;
          }).take(10).toList();
        }
        
        if (batch.isNotEmpty) {
          for (var vid in batch) {
            // 1. Create a "Fingerprint" (Lowercase, no spaces)
            final String newTitle = vid.title.toLowerCase().trim();
            
            // 2. Check if this title already exists in the current queue
            bool isDuplicate = _dynamicQueue.any((existingItem) {
              return existingItem.title.toLowerCase().trim() == newTitle;
            });

            // 3. Only add if it's a fresh track
            if (!isDuplicate) {
              _dynamicQueue.add(MediaItem(
                id: vid.id.value, 
                title: vid.title, 
                artist: vid.author, 
                duration: vid.duration, 
                artUri: Uri.parse(vid.thumbnails.highResUrl)
              ));
            } else {
              print('🚫 [Ghost DJ] Blocking duplicate: $newTitle');
            }
          }
          queue.add(List.from(_dynamicQueue));
          print('✨ [Ghost DJ] SUCCESS! Added ${batch.length} tracks to the queue.');
        } else {
          print('❌ [Ghost DJ] Both Plan A and B failed. DJ is taking a break.');
        }
      } catch (e) {
        print('⚠️ [Ghost DJ] Complete System Failure: $e');
      } finally {
        _isSearching = false; 
      }
    }

    if (_isDownloading) return;
    if (_currentIndex + 1 < _dynamicQueue.length) {
      final nextItem = _dynamicQueue[_currentIndex + 1];
      final dir = await getApplicationDocumentsDirectory();
      
      final finalFile = File('${dir.path}/${nextItem.id}.mp4');
      final tempFile = File('${dir.path}/${nextItem.id}.temp'); 

      if (await finalFile.exists() && await finalFile.length() > 50000) return;

      _isDownloading = true; 
      try {
        print('👻 [Ghost Downloader] Fetching: ${nextItem.title}');
        final manifest = await _youtubeExplode.videos.streamsClient.getManifest(
          nextItem.id, 
          ytClients: [YoutubeApiClient.safari, YoutubeApiClient.androidVr]
        );
        final stream = _youtubeExplode.videos.streamsClient.get(manifest.audioOnly.withHighestBitrate());
        
        final fileStream = tempFile.openWrite();
        await stream.pipe(fileStream);
        await fileStream.flush();
        await fileStream.close();
        
        await tempFile.rename(finalFile.path);
        print('✅ [Ghost Downloader] Success. File safely locked and ready.');
        
        // 🚨 NEW: THE LIBRARIAN
        // Save the metadata so the Vault UI knows what this file is!
        final vaultBox = Hive.box<Song>('vault');
        await vaultBox.put(nextItem.id, Song(
          id: nextItem.id,
          title: nextItem.title,
          artist: nextItem.artist ?? 'Unknown Artist',
          thumbnailUrl: nextItem.artUri?.toString() ?? '',
        ));
        
      } catch (e) {
        print('❌ [Ghost Downloader] Error. Skipping cache for this track.');
        if (await tempFile.exists()) await tempFile.delete(); 
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

  @override
  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    // 🚨 Standard Flutter Reorderable math fix
    if (oldIndex < newIndex) newIndex -= 1;
    
    // 1. Move it in our local List
    final item = _dynamicQueue.removeAt(oldIndex);
    _dynamicQueue.insert(newIndex, item);
    
    // 2. Notify the UI
    queue.add(List.from(_dynamicQueue));
    
    // 3. Update the Current Index if the playing song was moved
    // (This keeps the music from stopping when you drag the active song)
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem item) async {
    _dynamicQueue.removeWhere((q) => q.id == item.id);
    queue.add(List.from(_dynamicQueue));
  }

  Future<void> clearQueue() async {
    if (_dynamicQueue.isEmpty) return;

    // Keep the currently playing song, remove everything else
    final MediaItem? currentItem = mediaItem.value;
    
    _dynamicQueue.clear();
    
    if (currentItem != null) {
      _dynamicQueue.add(currentItem);
      _currentIndex = 0;
    } else {
      _currentIndex = -1;
    }

    // Update the UI stream
    queue.add(List.from(_dynamicQueue));
    print('🧹 [AudioHandler] Queue cleared (Current song preserved)');
  }

  // 🚨 NEW: EQ Controllers for the UI
  AndroidEqualizer get equalizer => _equalizer;

  Future<void> toggleEQ(bool enable) async {
    await _equalizer.setEnabled(enable);
  }

  void dispose() {
    _youtubeExplode.close();
    _player.dispose();
  }
}