import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jaiva/models/playlist.dart';
import 'package:jaiva/models/song.dart';

class AddToPlaylistSheet extends StatelessWidget {
  final Song song;

  const AddToPlaylistSheet({super.key, required this.song});

  // A static helper method so we can call this from ANY screen easily
  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828), // Slightly lighter than the background
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5, // Takes up exactly 50% of screen
        child: AddToPlaylistSheet(song: song),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- HEADER ---
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Add to Playlist',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        
        // --- PLAYLIST LIST ---
        Expanded(
          child: ValueListenableBuilder<Box<Playlist>>(
            valueListenable: Hive.box<Playlist>('playlists').listenable(),
            builder: (context, box, _) {
              if (box.isEmpty) {
                return const Center(
                  child: Text(
                    'You have no playlists yet.\nGo to Your Library to create one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: box.length,
                itemBuilder: (context, index) {
                  final playlist = box.getAt(index);
                  if (playlist == null) return const SizedBox.shrink();

                  // 1. Check if the song is already in this playlist to prevent duplicates
                  final alreadyExists = playlist.songs.any((s) => s.id == song.id);

                  return ListTile(
                    leading: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.grey),
                    ),
                    title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${playlist.songs.length} songs', style: const TextStyle(color: Colors.grey)),
                    trailing: alreadyExists
                        ? const Icon(Icons.check_circle, color: Colors.green) // Shows green check if already added
                        : const Icon(Icons.add_circle_outline, color: Colors.white54),
                    onTap: () {
                      if (!alreadyExists) {
                        // 2. Add the song to a new list
                        final updatedSongs = List<Song>.from(playlist.songs)..add(song);
                        
                        // 3. Create an updated Playlist object
                        final updatedPlaylist = Playlist(
                          id: playlist.id,
                          name: playlist.name,
                          songs: updatedSongs,
                        );

                        // 4. Save the updated playlist back into Hive at the exact same index
                        box.putAt(index, updatedPlaylist);
                        
                        // 5. Close the sheet and show a success message
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to ${playlist.name}', style: const TextStyle(color: Colors.white)), 
                            backgroundColor: Colors.grey[900],
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        // If it's already in the playlist, just tell them
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Already in ${playlist.name}', style: const TextStyle(color: Colors.white)), 
                            backgroundColor: Colors.grey[900],
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}