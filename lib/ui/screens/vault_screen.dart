import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/models/song.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:jaiva/core/background_audio_handler.dart'; // Import your handler!

class VaultScreen extends StatelessWidget {
  final dynamic audioHandler; // Pass your BackgroundAudioHandler here

  const VaultScreen({Key? key, required this.audioHandler}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('The Vault 🗄️', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        // 🚨 Listens to the Hive Box in real-time!
        valueListenable: Hive.box<Song>('vault').listenable(),
        builder: (context, Box<Song> box, _) {
          final offlineSongs = box.values.toList().reversed.toList();

          if (offlineSongs.isEmpty) {
            return const Center(
              child: Text(
                'Your Vault is empty.\nStart listening to download songs!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: offlineSongs.length,
            itemBuilder: (context, index) {
              final song = offlineSongs[index];

              return Dismissible(
                key: Key(song.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 30),
                ),
                onDismissed: (direction) => _deleteFromVault(song.id, box),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song.thumbnailUrl,
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 55, height: 55, color: Colors.white10,
                        child: const Icon(Icons.music_note, color: Colors.white54),
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    song.artist,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: const Icon(Icons.offline_pin_rounded, color: Colors.deepPurpleAccent),
                  onTap: () {
                    // 🚨 Play directly from the Vault!
                    audioHandler.playMediaItem(MediaItem(
                      id: song.id,
                      title: song.title,
                      artist: song.artist,
                      artUri: Uri.parse(song.thumbnailUrl),
                    ));
                  },
                ),
              );
            },
          );
        },
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