import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jaiva/models/song.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';
import 'package:jaiva/ui/widgets/kinetic_song_tile.dart';

class VaultScreen extends StatelessWidget {
  final dynamic audioHandler; // Pass your BackgroundAudioHandler here

  const VaultScreen({Key? key, required this.audioHandler}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'The Vault 🗄️',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 🎨 Kinetic Vault: Aura Orb Background
          const AuraOrb(
            auraValue: 0.2, // Deep Indigo/Emerald for the Dark Tech Vault
            size: 400.0,
          ),

          // Main content
          ValueListenableBuilder(
            // 🚨 Listens to the Hive Box in real-time!
            valueListenable: Hive.box<Song>('vault').listenable(),
            builder: (context, Box<Song> box, _) {
              final offlineSongs = box.values.toList().reversed.toList();

              if (offlineSongs.isEmpty) {
                return Center(
                  child: Text(
                    'Your Vault is empty.\nStart listening to download songs!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                );
              }

              // 👇 FIX: Replaced MasonryGridView with the stable GridView.builder
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16.0, // Tweaked spacing for the new cards
                  crossAxisSpacing: 16.0,
                  childAspectRatio: 0.75, // Keeps the cards tall and sleek!
                ),
                padding: const EdgeInsets.all(16.0).copyWith(bottom: 120), // Added bottom padding so the mini-player doesn't cover the last row
                itemCount: offlineSongs.length,
                itemBuilder: (context, index) {
                  final song = offlineSongs[index];
                  
                  return KineticSongTile(
                    // 👇 FIX: Added ValueKey to prevent rendering crashes
                    key: ValueKey(song.id),
                    song: song,
                    bpm: 120.0, // Will be dynamic later
                    genre: 'Offline',
                    onTap: () {
                      audioHandler.playMediaItem(MediaItem(
                        id: song.id,
                        title: song.title,
                        artist: song.artist,
                        artUri: Uri.parse(song.thumbnailUrl),
                      ));
                    },
                    onLongPress: () {
                      _deleteFromVault(song.id, box);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // 🗑️ The Trash Can Logic
  Future<void> _deleteFromVault(String songId, Box<Song> box) async {
    // 1. Remove from Database
    await box.delete(songId); 
    
    // 2. Delete the actual .mp4 file to free up phone storage!
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$songId.mp4');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Vault Delete Error: $e');
    }
  }
}