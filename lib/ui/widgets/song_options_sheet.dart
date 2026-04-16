import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/add_to_playlist_sheet.dart';

class SongOptionsSheet extends ConsumerWidget {
  final Song song;

  const SongOptionsSheet({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828), // Spotify elevated dark grey
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SongOptionsSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- HEADER: Song Info ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: song.thumbnailUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artist,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          // --- ACTION: Add to Queue ---
          ListTile(
            leading: const Icon(Icons.queue_music, color: Colors.white),
            title: const Text('Add to queue', style: TextStyle(color: Colors.white, fontSize: 16)),
            onTap: () {
              // Add to the AudioService Queue
              ref.read(audioHandlerProvider).addQueueItem(
                MediaItem(
                  id: song.id,
                  title: song.title,
                  artist: song.artist,
                  artUri: Uri.parse(song.thumbnailUrl),
                ),
              );
              
              Navigator.pop(context); // Close the sheet
              
              // Show a quick success message!
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added to queue'),
                  backgroundColor: const Color(0xFF1DB954),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.do_not_disturb_alt, color: Colors.redAccent),
            title: Text(
              "Don't recommend this track",
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
            ),
            onTap: () async {
              // 1. Add to Hive Blacklist
              final blacklistBox = Hive.box('blacklist');
              await blacklistBox.put(song.id, song.title);

              // 2. Close sheet and notify user
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🚫 ${song.title} added to Blacklist.', 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          // --- ACTION: Add to Playlist ---
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white),
            title: const Text('Add to playlist', style: TextStyle(color: Colors.white, fontSize: 16)),
            onTap: () {
              Navigator.pop(context); // Close THIS sheet...
              AddToPlaylistSheet.show(context, song); // ...and open the playlist sheet!
            },
          ),
          
          const SizedBox(height: 8), // Bottom padding
        ],
      ),
    );
  }
}