import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/core/theme_provider.dart';
import 'package:jaiva/core/cache_config.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/heart_button.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/ui/screens/queue_screen.dart';
import 'package:jaiva/ui/widgets/add_to_playlist_sheet.dart';
import 'package:jaiva/core/download_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jaiva/ui/widgets/playback_progress_bar.dart';
import 'package:jaiva/ui/widgets/synchronized_lyrics.dart';
import 'package:jaiva/ui/widgets/eq_mixer.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final themeAsync = ref.watch(themeProvider);
    final theme = themeAsync.valueOrNull ?? ThemeColors.defaultColors();
    final audioHandler = ref.watch(audioHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        final imageUrl = mediaItem?.artUri?.toString() ?? '';

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('NOW PLAYING', style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 2)),
            centerTitle: true,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.vibrant.withOpacity(0.8), theme.dominant.withOpacity(0.9), Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              RepaintBoundary(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    
                    // --- TOGGLE LYRICS BUTTON (Top Right) ---
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: IconButton(
                          icon: Icon(_showLyrics ? Icons.lyrics : Icons.lyrics_outlined, color: _showLyrics ? Colors.green : Colors.white, size: 28),
                          onPressed: () {
                            setState(() {
                              _showLyrics = !_showLyrics;
                            });
                          },
                        ),
                      ),
                    ),
                    
                    // --- FLIP FLOP: Album Art OR Lyrics ---
                    Expanded(
                      child: _showLyrics
                          ? const SynchronizedLyrics() // 🎤 SHOW LYRICS
                          : GestureDetector(
                              onHorizontalDragEnd: (details) {
                                if (details.primaryVelocity! > 0) {
                                  audioHandler.skipToPrevious();
                                } else if (details.primaryVelocity! < 0) {
                                  audioHandler.skipToNext();
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ), // Adds a premium drop shadow
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20), // Premium rounded corners
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    cacheManager: CacheConfig.imageCache,
                                    memCacheWidth: 600,
                                    fit: BoxFit.cover, // 👈 THE MAGIC WORD: Crops it perfectly into a square instead of squishing!
                                    errorWidget: (context, error, stackTrace) => 
                                      Container(color: Colors.grey.shade800, child: const Icon(Icons.music_note, size: 100, color: Colors.white)),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mediaItem?.title ?? 'No Track',
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mediaItem?.artist ?? 'Unknown Artist',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (mediaItem != null)
                            ...([
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                                onPressed: () {
                                  final currentSong = Song(
                                    id: mediaItem.id,
                                    title: mediaItem.title,
                                    artist: mediaItem.artist ?? 'Unknown',
                                    thumbnailUrl: mediaItem.artUri?.toString() ?? '',
                                  );
                                  AddToPlaylistSheet.show(context, currentSong);
                                },
                              ),
                              HeartButton(currentSong: Song(
                                id: mediaItem.id,
                                title: mediaItem.title,
                                artist: mediaItem.artist ?? '',
                                thumbnailUrl: imageUrl,
                              )),
                            ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 🚨 DROP THE NEW PROGRESS BAR HERE!
                    const PlaybackProgressBar(),
                    
                    const SizedBox(height: 24),
                    
                    // Your existing Play / Pause / Skip buttons go here...
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          onPressed: () => audioHandler.skipToPrevious(),
                        ),
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, stateSnapshot) {
                            final playing = stateSnapshot.data?.playing ?? false;
                            return Container(
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              child: IconButton(
                                iconSize: 50,
                                icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black),
                                onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                              ),
                            );
                          }
                        ),
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          onPressed: () => audioHandler.skipToNext(),
                        ),
                        IconButton(
                          iconSize: 28,
                          icon: const Icon(Icons.queue_music, color: Colors.white70),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const FractionallySizedBox(
                                heightFactor: 0.9,
                                child: QueueScreen(),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 30),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => EQMixer(equalizer: audioHandler.equalizer),
                            );
                          },
                        ),
                        ValueListenableBuilder<Box<Song>>(
                          valueListenable: Hive.box<Song>('downloads').listenable(),
                          builder: (context, box, _) {
                            final isDownloaded = box.values.any((s) => s.id == mediaItem?.id);

                            return IconButton(
                              iconSize: 28,
                              icon: Icon(
                                isDownloaded ? Icons.offline_pin : Icons.download_for_offline_outlined,
                                color: isDownloaded ? Colors.green : Colors.white,
                              ),
                              onPressed: () {
                                if (mediaItem != null && !isDownloaded) {
                                  final currentSong = Song(
                                    id: mediaItem.id,
                                    title: mediaItem.title,
                                    artist: mediaItem.artist ?? 'Unknown',
                                    thumbnailUrl: mediaItem.artUri?.toString() ?? '',
                                  );
                                  // Trigger the download!
                                  DownloadService.downloadSong(context, currentSong);
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
