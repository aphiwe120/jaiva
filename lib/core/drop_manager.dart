import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/models/playlist.dart'; // 👈 Added Playlist import

class DropManager {
  final _supabase = Supabase.instance.client;

  // 1. Generates a cool code like "JAIVA-9X2F"
  String _generateDropCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(Iterable.generate(
        4, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
    return 'JAIVA-$code';
  }

  // 2. Uploads the playlist to the Cloud
  Future<String?> createDrop(String playlistName, List<Song> playlistSongs) async {
    try {
      // 🚨 THE AUTH BYPASS: Commented out until we build the email login update!
      // final userId = _supabase.auth.currentUser?.id;
      // if (userId == null) return null;

      final dropCode = _generateDropCode();

      // Convert our local Song objects into a simple JSON list
      final List<Map<String, dynamic>> trackData = playlistSongs.map((song) => {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'thumbnailUrl': song.thumbnailUrl,
        'genre': song.genre,
      }).toList();

      await _supabase.from('shared_drops').insert({
        'drop_code': dropCode,
        'creator_id': 'anonymous_v5_user', // 👈 Temp ID until auth is built
        'playlist_name': playlistName,
        'tracks': trackData,
      });

      print('🚀 [The Drop] Playlist secured at code: $dropCode');
      return dropCode;

    } catch (e) {
      print('❌ [The Drop] Upload failed: $e');
      return null;
    }
  }

  // 3. Fetches the Cloud Playlist and converts it for the DJ
  Future<Playlist?> getDrop(String dropCode) async {
    try {
      // 🚨 Make sure 'drop_code' and 'shared_drops' exactly match your Supabase columns!
      final response = await _supabase
          .from('shared_drops')
          .select()
          .eq('drop_code', dropCode.toUpperCase())
          .single();

      final String name = response['playlist_name'];
      final List<dynamic> rawTracks = response['tracks'];

      // Convert the raw JSON back into Jaiva Song objects
      List<Song> importedSongs = rawTracks.map((json) => Song(
        id: json['id'],
        title: json['title'],
        artist: json['artist'],
        thumbnailUrl: json['thumbnailUrl'],
        genre: json['genre'] ?? 'Imported',
      )).toList();

      print('🛬 [The Drop] Successfully fetched "$name" with ${importedSongs.length} tracks.');
      
      // 🚨 Return a Hive-ready Playlist object directly to the UI
      return Playlist(
        id: 'drop_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        songs: importedSongs,
      );

    } catch (e) {
      print('❌ [The Drop] Fetch failed. Invalid code? Error: $e');
      return null;
    }
  }
}