import 'dart:async';
import 'dart:io'; 
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Needed for ValueNotifier
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:jaiva/core/music_repository.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive/hive.dart';
import 'package:jaiva/models/song.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final AndroidEqualizer _equalizer = AndroidEqualizer(); 
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_equalizer],
    ),
  );
  
  final MusicRepository _repository;
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  final List<MediaItem> _dynamicQueue = [];
  final Set<String> _processedCache = {}; 
  final Map<String, String> _genres = {}; 
  
  int _currentIndex = -1;
  bool _isDownloading = false;
  bool _isSearching = false; 
  bool isSmartShuffleEnabled = true;
  DateTime _lastAutoSkip = DateTime.fromMillisecondsSinceEpoch(0); 

  // 👇 The "Brain" of the Ghost DJ UI
  final ValueNotifier<bool> discoveryModeNotifier = ValueNotifier<bool>(false);

  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: [],
  );

  // 2. CONSTRUCTOR
  BackgroundAudioHandler(this._repository) {
    _init();
  }

  // 👇 The action that flips the switch from the UI
  void toggleDiscoveryMode() {
    discoveryModeNotifier.value = !discoveryModeNotifier.value;
    print('🔮 [Ghost DJ] Global Discovery is now: ${discoveryModeNotifier.value ? "ON" : "OFF"}');
  }

  // 3. INITIALIZATION
  Future<void> _init() async {
    try {
      _cleanCacheIfTooBig();
      
      if (Platform.isAndroid || Platform.isIOS) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      }
      
      await _player.setAudioSource(_playlist);

      _player.playbackEventStream.listen((PlaybackEvent event) async {
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
          if (now.difference(_lastAutoSkip).inSeconds < 2) { 
            print('🛑 [LOOP BREAKER] Real hardware loop detected. Stopping.');
            Future.microtask(() => _player.stop()); 
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
    _dynamicQueue.clear(); 
    _dynamicQueue.add(item);
    _currentIndex = 0;

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

    _handlePlayback(item);
  }

  Future<void> _handlePlayback(MediaItem item) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/${item.id}.mp4');

      if (await localFile.exists() && await localFile.length() > 50000) {
        print('🎧 [AudioHandler] Playing cached file.');
        final audioSource = AudioSource.uri(Uri.file(localFile.path), tag: item);
        await _playlist.clear();
        await _playlist.add(audioSource);
        _player.play();
        
        if (isSmartShuffleEnabled) {
          _queueNextGhostTrack(item.title).then((_) {
            _precacheNextSong(); 
          });
        } else {
          _precacheNextSong(); 
        }
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

      var videoData = await _youtubeExplode.videos.get(item.id);
      String songGenre = "Unknown";
      
      if (videoData.keywords.isNotEmpty) {
        songGenre = videoData.keywords.first;
        
        final List<String> knownGenres = [
          'amapiano', 'maskandi', 'gqom', 'kwaito', 'afrobeat', 'afrobeats', 
          'rnb', 'hip hop', 'hip-hop', 'house', 'deep house', 'sgija', 
          'pop', 'soul', 'jazz', 'gospel'
        ];

        for (var tag in videoData.keywords) {
          if (knownGenres.contains(tag.toLowerCase())) {
             songGenre = tag[0].toUpperCase() + tag.substring(1).toLowerCase();
             break; 
          }
        }
      }

      if (!_processedCache.contains(item.id)) {
        uploadToLibrarian(cacheFile.path, item.title, songGenre);
        _processedCache.add(item.id);
      }

      _genres[item.id] = songGenre; 
      final vaultBox = Hive.box<Song>('vault');
      await vaultBox.put(item.id, Song(
        id: item.id,
        title: item.title,
        artist: item.artist ?? 'Unknown Artist',
        thumbnailUrl: item.artUri?.toString() ?? '',
        genre: songGenre,
      ));

      await _playlist.clear();
      await _playlist.add(ByteAudioSource(audioBytes, contentType: audioStreamInfo.container.name == 'webm' ? 'audio/webm' : 'audio/mp4', tag: item));
      _player.play();
      
      if (isSmartShuffleEnabled) {
        _queueNextGhostTrack(item.title).then((_) {
          _precacheNextSong(); 
        });
      } else {
        _precacheNextSong(); 
      }
      
    } catch (e) {
      print('❌ Playback failed: $e');
      Future.delayed(const Duration(seconds: 2), () => skipToNext());
    }
  }


  // 5. GHOST DJ & SMART SHUFFLE

  Future<String> _extractGenreFromVideo(String videoId) async {
    try {
      var videoData = await _youtubeExplode.videos.get(videoId);
      String genre = "Unknown";
      
      if (videoData.keywords.isNotEmpty) {
        genre = videoData.keywords.first;
        
        final List<String> knownGenres = [
          'amapiano', 'maskandi', 'gqom', 'kwaito', 'afrobeat', 'afrobeats', 
          'rnb', 'hip hop', 'hip-hop', 'house', 'deep house', 'sgija', 
          'pop', 'soul', 'jazz', 'gospel'
        ];

        for (var tag in videoData.keywords) {
          if (knownGenres.contains(tag.toLowerCase())) {
            genre = tag[0].toUpperCase() + tag.substring(1).toLowerCase();
            break;
          }
        }
      }
      return genre;
    } catch (e) {
      print('⚠️ [Genre Extractor] Error: $e');
      return 'Unknown';
    }
  }

  Future<void> _queueNextGhostTrack(String currentTitle) async {
    if (_isSearching) return;
    _isSearching = true;

    try {
      String? nextTitle = await getGhostRecommendation(currentTitle);
      
      if (nextTitle == null) {
        print('⏳ [Ghost DJ] Vault empty. Waiting 25s for DNA extraction...');
        await Future.delayed(const Duration(seconds: 40)); 
        nextTitle = await getGhostRecommendation(currentTitle);
      }

      if (nextTitle != null) {
        final searchResults = await _youtubeExplode.search.search(nextTitle);
        
        if (searchResults.isNotEmpty) {
          Video? bestMatch;

          for (var video in searchResults.take(10)) {
            final titleLower = video.title.toLowerCase();
            final duration = video.duration ?? Duration.zero;

            if (duration.inSeconds < 90 || duration.inMinutes > 10) continue;

            if (titleLower.contains('music video') || 
                titleLower.contains('visualizer') || 
                titleLower.contains('live') || 
                titleLower.contains('mix') ||
                titleLower.contains('mashup') ||
                titleLower.contains('full album')) {
              continue; 
            }

            bestMatch = video;
            break; 
          }

          bestMatch ??= searchResults.firstWhere(
            (v) => (v.duration?.inSeconds ?? 0) >= 90 && (v.duration?.inMinutes ?? 0) <= 10,
            orElse: () => searchResults.first, 
          );

          if (!_dynamicQueue.any((q) => q.title == bestMatch!.title)) {
            final extractedGenre = await _extractGenreFromVideo(bestMatch.id.value);
            
            _dynamicQueue.add(MediaItem(
              id: bestMatch.id.value, 
              title: bestMatch.title, 
              artist: bestMatch.author, 
              duration: bestMatch.duration, 
              artUri: Uri.parse(bestMatch.thumbnails.highResUrl)
            ));
            _genres[bestMatch.id.value] = extractedGenre;
            queue.add(List.from(_dynamicQueue));
            print('🎧 [Ghost DJ] SUCCESS: Injected CLEAN audio for: $nextTitle');
          }
        }
      }
    } catch (e) {
      print('⚠️ [Ghost DJ] Error: $e');
    } finally {
      _isSearching = false;
    }
  }

  Future<void> _precacheNextSong() async {
    if (isSmartShuffleEnabled && _dynamicQueue.length <= _currentIndex + 2) {
      if (_isSearching) return;
      _isSearching = true;
      
      try {
        final seedTrack = _dynamicQueue.isNotEmpty ? _dynamicQueue.last : null;
        if (seedTrack == null) return;

        final video = await _youtubeExplode.videos.get(seedTrack.id).timeout(const Duration(seconds: 5));
        var related = await _youtubeExplode.videos.getRelatedVideos(video).timeout(const Duration(seconds: 5));
        
        if (related != null && related.isNotEmpty) {
          for (var vid in related.take(10)) {
            if (!_dynamicQueue.any((q) => q.id == vid.id.value)) {
              final relatedGenre = await _extractGenreFromVideo(vid.id.value);
              
              _dynamicQueue.add(MediaItem(
                id: vid.id.value, 
                title: vid.title, 
                artist: vid.author, 
                duration: vid.duration, 
                artUri: Uri.parse(vid.thumbnails.highResUrl)
              ));
              _genres[vid.id.value] = relatedGenre;
            }
          }
          queue.add(List.from(_dynamicQueue));
        }
      } catch (e) {
        print('⚠️ [Ghost DJ] Precaching batch failed: $e');
      } finally {
        _isSearching = false; 
      }
    }

    if (_isDownloading) return;
    if (_currentIndex + 1 < _dynamicQueue.length) {
      final nextItem = _dynamicQueue[_currentIndex + 1];
      final dir = await getApplicationDocumentsDirectory();
      final finalFile = File('${dir.path}/${nextItem.id}.mp4');

      if (await finalFile.exists() && await finalFile.length() > 50000) {
         if (!_processedCache.contains(nextItem.id)) {
           final genre = _genres[nextItem.id] ?? 'Unknown';
           uploadToLibrarian(finalFile.path, nextItem.title, genre);
           _processedCache.add(nextItem.id);
         }
         return;
      }

      _isDownloading = true; 
      try {
        final manifest = await _youtubeExplode.videos.streamsClient.getManifest(nextItem.id, ytClients: [YoutubeApiClient.safari, YoutubeApiClient.androidVr]);
        final stream = _youtubeExplode.videos.streamsClient.get(manifest.audioOnly.withHighestBitrate());
        
        List<int> audioBytes = [];
        await for (final chunk in stream) { audioBytes.addAll(chunk); }
        await finalFile.writeAsBytes(audioBytes);
        
        var videoData = await _youtubeExplode.videos.get(nextItem.id);
        String nextGenre = "Unknown";
        
        if (videoData.keywords.isNotEmpty) {
          nextGenre = videoData.keywords.first;
          
          final List<String> knownGenres = [
            'amapiano', 'maskandi', 'gqom', 'kwaito', 'afrobeat', 'afrobeats', 
            'rnb', 'hip hop', 'hip-hop', 'house', 'deep house', 'sgija', 
            'pop', 'soul', 'jazz', 'gospel'
          ];

          for (var tag in videoData.keywords) {
            if (knownGenres.contains(tag.toLowerCase())) {
               nextGenre = tag[0].toUpperCase() + tag.substring(1).toLowerCase();
               break; 
            }
          }
        }
        
        _genres[nextItem.id] = nextGenre; 
        if (!_processedCache.contains(nextItem.id)) {
           uploadToLibrarian(finalFile.path, nextItem.title, nextGenre);
           _processedCache.add(nextItem.id);
        }

        final vaultBox = Hive.box<Song>('vault');
        await vaultBox.put(nextItem.id, Song(
          id: nextItem.id,
          title: nextItem.title,
          artist: nextItem.artist ?? 'Unknown Artist',
          thumbnailUrl: nextItem.artUri?.toString() ?? '',
          genre: nextGenre,
        ));
      } catch (e) {
        print('❌ [Ghost Downloader] Error: $e');
      } finally {
        _isDownloading = false; 
      }
    }
  }

  // 6. CLOUD LIBRARIAN (Hugging Face)
  Future<void> uploadToLibrarian(String filePath, String songTitle, String genre) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('⚠️ [Librarian] No user logged in. Skipping DNA upload.');
      return;
    }

    final url = Uri.parse('https://aphiwe-mntambo-jaiva-librarian.hf.space/api/extract');
    
    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['user_id'] = userId; 
      request.fields['song_title'] = songTitle;
      request.fields['genre'] = genre;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      print('🚀 [Librarian] Analyzing DNA for: $songTitle (User: $userId)');
      var streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('✅ [Librarian] DNA secured in Cloud Vault.');
      } else {
        print('⚠️ [Librarian] Failed to secure DNA: ${response.statusCode}');
      }
    } catch (e) {
      print('🔌 [Librarian] Offline/Error: $e');
    }
  }

  // 6.5 GHOST RECOMMENDATION (Now with Global Discovery!)
  Future<String?> getGhostRecommendation(String currentTitle) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    // 👇 Reads directly from the UI button now!
    final bool isDiscoveryMode = discoveryModeNotifier.value; 
    
    Uri url;
    if (isDiscoveryMode) {
      print('🌍 [Ghost DJ] Entering GLOBAL DISCOVERY mode...');
      url = Uri.parse('https://jaiva-api.onrender.com/api/discover?current_song=${Uri.encodeComponent(currentTitle)}&user_id=$userId');
    } else {
      print('🏠 [Ghost DJ] Searching Personal Vault...');
      url = Uri.parse('https://jaiva-api.onrender.com/api/recommend?current_song=${Uri.encodeComponent(currentTitle)}&user_id=$userId');
    }

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['source'] == 'Global Discovery') {
           print('🔥 [Ghost DJ] FOUND A GLOBAL BANGER: ${data['next_up']}');
        }
        
        return data['next_up'] as String?;
      } else if (response.statusCode == 404) {
        print('🤖 [Ghost DJ] Vault empty or song not found. Falling back to YouTube related tracks.');
      }
    } catch (e) {
      print('🤖 [Ghost DJ] AI Error: $e');
    }
    return null;
  }

  // 7. QUEUE CONTROL
  @override
  Future<void> skipToNext() async {
    if (_currentIndex + 1 < _dynamicQueue.length) {
      _currentIndex++;
      final nextItem = _dynamicQueue[_currentIndex];
      mediaItem.add(nextItem);
      _handlePlayback(nextItem);
    }
  }

  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _dynamicQueue.length) return;
    _currentIndex = index;
    final targetItem = _dynamicQueue[_currentIndex];
    mediaItem.add(targetItem);
    _handlePlayback(targetItem);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      seek(Duration.zero);
    } else if (_currentIndex > 0) {
      skipToQueueItem(_currentIndex - 1);
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
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _dynamicQueue.removeAt(oldIndex);
    _dynamicQueue.insert(newIndex, item);
    queue.add(List.from(_dynamicQueue));
    if (_currentIndex == oldIndex) _currentIndex = newIndex;
  }

  @override
  Future<void> removeQueueItem(MediaItem item) async {
    _dynamicQueue.removeWhere((q) => q.id == item.id);
    queue.add(List.from(_dynamicQueue));
  }

  Future<void> clearQueue() async {
    _dynamicQueue.clear();
    queue.add([]);
    _currentIndex = -1;
  }

  Future<void> playPlaylist(List<MediaItem> mediaItems, {int startIndex = 0}) async {
    if (mediaItems.isEmpty) return;

    _dynamicQueue.clear();
    _dynamicQueue.addAll(mediaItems);
    queue.add(List.from(_dynamicQueue));

    _currentIndex = startIndex.clamp(0, mediaItems.length - 1);
    
    final targetItem = _dynamicQueue[_currentIndex];
    mediaItem.add(targetItem);
    
    _handlePlayback(targetItem);
  }

  // 8. HELPERS & LIFECYCLE
  AndroidEqualizer get equalizer => _equalizer;
  Future<void> toggleEQ(bool enable) async => await _equalizer.setEnabled(enable);

  @override Future<void> play() => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> seek(Duration position) => _player.seek(position);
  @override Future<void> stop() => _player.stop();

  void dispose() {
    _youtubeExplode.close();
    _player.dispose();
  }

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
}