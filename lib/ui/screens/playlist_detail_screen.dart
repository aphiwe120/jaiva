import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 Added for Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jaiva/models/playlist.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/core/drop_manager.dart'; // 👈 Added DropManager
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/song_options_sheet.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';
import 'package:jaiva/ui/widgets/kinetic_song_tile.dart';
import 'package:jaiva/models/song.dart';

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
        // 🚀 THE EXPORTER BUTTON
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF00E676)),
            tooltip: 'Share Drop',
            onPressed: () {
              // Pull the absolute latest version of the playlist from Hive before sharing
              final currentPlaylist = Hive.box<Playlist>('playlists').values.firstWhere(
                (p) => p.id == playlist.id,
                orElse: () => playlist,
              );

              if (currentPlaylist.songs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cannot share an empty playlist!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.redAccent,
                  )
                );
                return;
              }

              // Trigger the Drop Dialog!
              _showShareDropDialog(context, currentPlaylist.name, currentPlaylist.songs);
            },
          ),
          const SizedBox(width: 8), // Padding
        ],
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

                // 🚨 THE HIVE CASTING FIX 🚨
                // Forces Hive to recognize the raw data as actual Jaiva Song objects!
                final List<Song> songs = List<Song>.from(currentPlaylist.songs);

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

                // 🚨 THE REORDERABLE LIST FIX 🚨
                return ReorderableListView.builder(
                  padding: const EdgeInsets.all(16.0).copyWith(bottom: 140),
                  itemCount: songs.length,
                  // 1. The Drag and Drop Logic
                  onReorder: (int oldIndex, int newIndex) {
                    // Flutter index calculation quirk
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }

                    // Clone the list so we don't mutate Hive data directly before saving
                    final List<Song> reorderedSongs = List<Song>.from(songs);
                    
                    // Pluck and insert
                    final movedSong = reorderedSongs.removeAt(oldIndex);
                    reorderedSongs.insert(newIndex, movedSong);

                    // Trigger your perfectly written save function!
                    _savePlaylistOrder(context, ref, reorderedSongs, currentPlaylist.id);
                  },
                  // 2. The UI Builder
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    
                    return Container(
                      // 🚨 CRITICAL: Every item in a ReorderableListView MUST have a unique Key!
                      key: ValueKey(song.id),
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          // The Drag Handle (Optional, but good for UX)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(Icons.drag_handle_rounded, color: Colors.white24),
                          ),
                          
                          // Expanded forces the tile to take up the rest of the horizontal space
                          Expanded(
                            child: SizedBox(
                              height: 120,  // ← Add this!
                              child: KineticSongTile(
                                song: song,
                                bpm: 120.0, 
                                genre: 'Playlist',
                                onTap: () {
                                  final audioHandler = ref.read(audioHandlerProvider);
                                  final mediaItems = songs.map((s) => MediaItem(
                                    id: s.id,
                                    title: s.title,
                                    artist: s.artist,
                                    artUri: Uri.tryParse(s.thumbnailUrl) ?? Uri.parse("https://via.placeholder.com/150"),
                                  )).toList();
                                  
                                  audioHandler.playPlaylist(mediaItems, startIndex: index);
                                },
                                onLongPress: () {
                                  SongOptionsSheet.show(context, song);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
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

  // ------------------------------------------------------------------
  // 📤 THE DROP DIALOG (Exporter UI)
  // ------------------------------------------------------------------
  void _showShareDropDialog(BuildContext context, String playlistName, List<Song> songs) async {
    // 1. Show a loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
    );

    // 2. Call the DropManager to hit Supabase
    final dropCode = await DropManager().createDrop(playlistName, songs);
    
    // 3. Close the loading spinner
    if (context.mounted) Navigator.pop(context); 

    if (dropCode != null && context.mounted) {
      // 4. Show the sleek Code Dialog
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF121212),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
          title: Text("PLAYLIST SECURED", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Send this code to your friends to drop this playlist into their vault.", style: GoogleFonts.outfit(color: Colors.white70)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05), 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5)),
                ),
                child: Text(
                  dropCode, 
                  style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CLOSE", style: GoogleFonts.outfit(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.copy, size: 20),
              label: Text("COPY", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: dropCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Code copied to clipboard!', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)), 
                    backgroundColor: const Color(0xFF00E676),
                    behavior: SnackBarBehavior.floating,
                  )
                );
                Navigator.pop(context);
              },
            )
          ],
        )
      );
    } else {
      // Error handling
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to secure drop. Check your connection.", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  void _savePlaylistOrder(BuildContext context, WidgetRef ref, List<Song> reorderedSongs, String playlistId) {
    try {
      final playlistBox = Hive.box<Playlist>('playlists');
      
      // Find the playlist and update it with the new song order
      final updatedPlaylist = Playlist(
        id: playlistId,
        name: playlist.name,
        songs: reorderedSongs,
      );
      
      // Save back to Hive
      playlistBox.put(playlistId, updatedPlaylist);
      
      // Optional: Show subtle confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist reordered!', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      print('❌ Error saving playlist order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save order', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}