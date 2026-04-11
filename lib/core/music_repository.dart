import 'dart:async';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/core/custom_ytmusic_client.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MusicRepository {
  final CustomYTMusicClient _customClient = CustomYTMusicClient();
  final YoutubeExplode _youtubeExplode = YoutubeExplode();

  MusicRepository() {
    _initialize();
  }

  /// Initialize (custom client is ready immediately)
  void _initialize() {
    print('🎵 [MusicRepository] Initializing Music Service...');
    print('✅ [MusicRepository] Ready for searches');
  }

  /// Search for tracks using REST API client
  Future<List<Song>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔎 [SearchTracks] Searching: "$query"');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      /// Use REST API client for search
      final songs = await _customClient.search(query);
      
      if (songs.isEmpty) {
        print('⚠️  [SearchTracks] No results found for "$query"');
        return [];
      }

      print('════════════════════════════════════════════════════════');
      print('✅ [SearchTracks] Found ${songs.length} matches for "$query"');
      if (songs.isNotEmpty) {
        print('✅ First result: "${songs.first.title}" by ${songs.first.artist}');
      }
      print('════════════════════════════════════════════════════════');
      
      return songs;
    } catch (e, stackTrace) {
      print('❌ [SearchTracks] Error: $e');
      print('Stack: $stackTrace');
      return [];
    }
  }

  /// Get trending/charts using REST API client  
  Future<List<Song>> getCharts() async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 [GetCharts] Fetching trending charts...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      /// Use REST API client for trending
      final songs = await _customClient.getTrending();
      
      if (songs.isEmpty) {
        print('⚠️  [GetCharts] No chart data available');
        return [];
      }

      final limited = songs.length > 20 ? songs.sublist(0, 20) : songs;
      
      print('════════════════════════════════════════════════════════');
      print('✅ [GetCharts] Found ${limited.length} trending songs');
      if (limited.isNotEmpty) {
        print('✅ Top: "${limited.first.title}" by ${limited.first.artist}');
      }
      print('════════════════════════════════════════════════════════');
      
      return limited;
    } catch (e, stackTrace) {
      print('❌ [GetCharts] Error: $e');
      print('Stack: $stackTrace');
      return [];
    }
  }

  /// Extract audio stream URL from videoId using YouTube Explode
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      print('🎵 [AudioExtractor] Extracting audio stream for: $videoId');
      
      /// Get the manifest for the video
      final manifest = await _youtubeExplode.videos.streamsClient.getManifest(videoId);
      
      /// Get the highest quality audio-only stream
      final audioStreamInfo = manifest.audioOnly.sortByBitrate().last;
      
      final audioUrl = audioStreamInfo.url.toString();
      print('✅ [AudioExtractor] Successfully extracted audio URL (bitrate: ${audioStreamInfo.bitrate})');
      
      return audioUrl;
    } catch (e, stackTrace) {
      print('❌ [AudioExtractor] Error extracting stream: $e');
      print('Stack: $stackTrace');
      throw Exception('Failed to extract audio stream for $videoId: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    print('🧹 [MusicRepository] Disposing resources...');
    _youtubeExplode.close();
    print('✅ [MusicRepository] Resources disposed');
  }
}