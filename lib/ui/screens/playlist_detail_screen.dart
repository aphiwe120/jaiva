import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jaiva/models/playlist.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/song_options_sheet.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';
import 'package:jaiva/ui/widgets/kinetic_song_tile.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          playlist.name,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 🎨 Kinetic Vault: Aura Orb Background
          AuraOrb(
            auraValue: 0.4 + (playlist.name.hashCode % 10) / 10,
            size: 400.0,
          ),

          // 🚨 Wrapped in Positioned.fill to prevent the Red Screen of Death!
          Positioned.fill(
            child: ValueListenableBuilder<Box<Playlist>>(
              // We listen to the Hive box so if you add a song, this screen updates instantly!
              valueListenable: Hive.box<Playlist>('playlists').listenable(),
              builder: (context, box, _) {
                // Find our specific playlist to get the most up-to-date songs
                final currentPlaylist = box.values.firstWhere(
                  (p) => p.id == playlist.id,
                  orElse: () => playlist,
                );

                final songs = currentPlaylist.songs;

                if (songs.isEmpty) {
                  return Center(
                    child: Text(
                      "This playlist is empty.\nGo find some music!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  );
                }

                return MasonryGridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12.0,
                  crossAxisSpacing: 12.0,
                  padding: const EdgeInsets.all(16.0).copyWith(bottom: 140),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return KineticSongTile(
                      song: song,
                      bpm: 120.0, // Will be dynamic later
                      genre: 'Playlist',
                      onTap: () {
                        // 🚨 NEW: Pass the entire playlist and start at the tapped song
                        final audioHandler = ref.read(audioHandlerProvider);
                        final mediaItems = songs.map((song) => MediaItem(
                          id: song.id,
                          title: song.title,
                          artist: song.artist,
                          artUri: Uri.parse(song.thumbnailUrl),
                        )).toList();
                        
                        audioHandler.playPlaylist(mediaItems, startIndex: index);
                      },
                      onLongPress: () {
                        SongOptionsSheet.show(context, song);
                      },
                    );
                  },
                );
              },
            ),
          ),

          // --- MINI PLAYER ---
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }
}