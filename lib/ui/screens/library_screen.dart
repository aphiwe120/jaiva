import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jaiva/models/playlist.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/jaiva_bottom_nav.dart';
import 'package:jaiva/ui/screens/playlist_detail_screen.dart';
import 'package:jaiva/ui/screens/liked_songs_screen.dart';

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
}