import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jaiva/models/playlist.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/jaiva_bottom_nav.dart';
import 'package:jaiva/ui/screens/playlist_detail_screen.dart';
import 'package:jaiva/ui/screens/liked_songs_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jaiva/core/drop_manager.dart';
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  void _createNewPlaylist(BuildContext context) {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Give your playlist a name.', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                final newPlaylist = Playlist(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: textController.text.trim(),
                  songs: [],
                );
                Hive.box<Playlist>('playlists').add(newPlaylist);
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Row(
          children: [
            CircleAvatar(radius: 16, backgroundImage: NetworkImage('https://via.placeholder.com/150')), 
            SizedBox(width: 12),
            Text('Your Library', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: () => _createNewPlaylist(context),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Color(0xFF00E676)),
            tooltip: 'Claim Drop',
            onPressed: () => _showClaimDropDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🚨 FIX: Wrapped the listenable builder area in Positioned.fill to prevent the crash!
          Positioned.fill(
            child: ValueListenableBuilder<Box<Song>>(
              valueListenable: Hive.box<Song>('likes').listenable(),
              builder: (likesContext, likesBox, _) {
                return ValueListenableBuilder<Box<Playlist>>(
                  valueListenable: Hive.box<Playlist>('playlists').listenable(),
                  builder: (context, box, _) {
                    final playlists = box.values.toList();
                    
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120), 
                      itemCount: playlists.length + 1, 
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            leading: Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.white70], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(4)
                              ),
                              child: const Icon(Icons.favorite, color: Colors.white),
                            ),
                            title: const Text('Liked Songs', style: TextStyle(color: Colors.white, fontSize: 16)),
                            subtitle: Text('Playlist • ${likesBox.length} songs', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            // 🚨 WIRE IT UP HERE!
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LikedSongsScreen(),
                                ),
                              );
                            },
                          );
                        }

                        final playlist = playlists[index - 1];
                        return ListTile(
                          leading: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.music_note, color: Colors.grey),
                          ),
                          title: Text(playlist.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                          subtitle: Text('Playlist • ${playlist.songs.length} songs', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          onTap: () {
                            // Navigate to Playlist Detail Screen
                            Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistDetailScreen(playlist: playlist),
            ),
          );
                          },
                        );
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
      bottomNavigationBar: const JaivaBottomNav(currentIndex: 2),
    );
  }
  // ------------------------------------------------------------------
  // 📥 THE CLAIM TERMINAL (UI)
  // ------------------------------------------------------------------
  void _showClaimDropDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), 
          side: BorderSide(color: Colors.white.withOpacity(0.1))
        ),
        title: Text(
          "CLAIM DROP", 
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)
        ),
        content: TextField(
          controller: codeController,
          style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters, // Auto-caps
          maxLength: 10, // 10 character limit
          decoration: InputDecoration(
            hintText: "0000000000",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
            counterText: "", // Hides the character counter below the line
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: const Color(0xFF00E676).withOpacity(0.5))
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00E676))
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.download, size: 20),
            label: Text("CLAIM", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              if (code.length == 10) {
                Navigator.pop(context); // Close the dialog
                await _processClaimDrop(context, code); // Pass to the DropManager
              }
            },
          )
        ],
      )
    );
  }

  // ------------------------------------------------------------------
  // ⚙️ THE CLAIM ENGINE (Backend Handshake)
  // ------------------------------------------------------------------
  Future<void> _processClaimDrop(BuildContext context, String code) async {
    // 1. Show a loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
    );

    // 2. Fetch the playlist from Supabase! 
    final downloadedPlaylist = await DropManager().getDrop(code);

    // 3. Close the loading spinner
    if (context.mounted) Navigator.pop(context);

    if (downloadedPlaylist != null && context.mounted) {
      // 4. Save to local Hive Box!
      final box = Hive.box<Playlist>('playlists');
      await box.put(downloadedPlaylist.id, downloadedPlaylist);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully secured: ${downloadedPlaylist.name}', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)), 
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        )
      );
    } else if (context.mounted) {
      // 5. Error handling for invalid codes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid or expired code.", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), 
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }
  
}