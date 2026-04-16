import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jaiva/models/song.dart';

class CustomYTMusicClient {
  final String baseUrl = 'https://authenticate-1-7cmf.onrender.com';

  Future<List<Song>> search(String query) async {
    final url = Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}');
    
    try {
      print('📡 [CustomYTMusic] Requesting: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 60));
      print('📡 [CustomYTMusic] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['status'] == 'success' && jsonResponse['data'] != null) {
          final List<dynamic> items = jsonResponse['data'];
          
          return items.map((item) {
            // 🚨 THE FIX: Hunt for ANY valid ID (Song, Album, or Playlist)
            final String extractedId = item['videoId'] ?? item['playlistId'] ?? item['browseId'] ?? '';
            
            // Determine if it's an album based on ID length or a provided 'type' flag
            final bool isAlbum = extractedId.length > 11 || item['type'] == 'album';

            return Song(
              id: extractedId,
              title: item['title'] ?? 'Unknown Title',
              // Some APIs use 'author' instead of 'artist' for albums
              artist: item['artist'] ?? item['author'] ?? 'Unknown Artist', 
              thumbnailUrl: item['thumbnail'] ?? '',
              // Tag it so the UI knows what it is!
              genre: isAlbum ? 'Album' : 'Search',
            );
          }).where((song) => song.id.isNotEmpty).toList(); 
        }
      }
    } catch (e) {
      print('❌ [CustomYTMusic] Search error: $e');
    }
    return [];
  }

  Future<List<Song>> getTrending() async {
    final url = Uri.parse('$baseUrl/trending');
    
    try {
      print('📡 [CustomYTMusic] Requesting Trending: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['status'] == 'success' && jsonResponse['data'] != null) {
          final List<dynamic> items = jsonResponse['data'];
          
          return items.map((item) {
            return Song(
              id: item['videoId'] ?? '',
              title: item['title'] ?? 'Trending Track',
              artist: item['artist'] ?? 'Unknown Artist',
              thumbnailUrl: item['thumbnail'] ?? '',
            );
          }).where((song) => song.id.isNotEmpty).toList();
        }
      }
    } catch (e) {
      print('❌ [CustomYTMusic] Trending error: $e');
    }
    return [];
  }
}