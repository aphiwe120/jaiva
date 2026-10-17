import 'package:jaiva/models/song.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class CustomYTMusicClient {
  final YoutubeExplode _yt = YoutubeExplode();

  // 1. 🔍 SEARCH LOCAL (Zero Server Costs)
  Future<List<Song>> search(String query) async {
    try {
      List<Song> results = [];
      print('📱 [LocalSearch] Scraping YT directly from phone for: $query');

      // --- 🎵 FETCH SONGS ---
      final videoResults = await _yt.search.search(query);
      
      // 🛑 THE BOUNCER: Keywords we absolutely DO NOT want in our clean music app
      final bannedKeywords = [
        'visualizer', 'visualiser', 'lyric', 'lyrics', 'reaction', 
        '8d', 'bass boosted', 'slowed', 'reverb', 'karaoke', 'instrumental',
        'tiktok', 'mashup'
      ];

      for (var video in videoResults) {
        
        // 1. DURATION FILTER
        final duration = video.duration?.inMinutes ?? 0;
        if (duration < 1 || duration > 20) continue; 
        
        // 2. THE BADGE CHECK (Title Filtering)
        final titleLower = video.title.toLowerCase();
        bool isGarbage = bannedKeywords.any((word) => titleLower.contains(word));
        
        if (isGarbage) {
          print('🗑️ [The Bouncer] Rejected trash track: ${video.title}');
          continue; // Skip this loop and throw the video away
        }

        // If it survives the Bouncer, add it to the vault!
        results.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          thumbnailUrl: video.thumbnails.highResUrl,
          genre: 'Search', 
        ));

        // Stop once we have 15 perfectly clean studio tracks
        if (results.length >= 15) break; 
      }

      return results;
    } catch (e) {
      print('❌ [LocalSearch] Error: $e');
      return [];
    }
  }

  // 2. 🔥 TRENDING LOCAL (The Fix)
  Future<List<Song>> getTrending() async {
    // Adding "official audio" forces YouTube to return single 3-5 minute 
    // studio tracks instead of 2-hour mixes, so they pass our duration filter!
    return await search("latest top amapiano hit songs official audio");
  }

  void dispose() {
    _yt.close();
  }
}