import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:jaiva/core/player_provider.dart';

// --- 1. THE LYRIC LINE MODEL ---
class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

// --- 2. THE STATE MODEL ---
class LyricsState {
  final bool isLoading;
  final List<LyricLine>? syncedLyrics;
  final String? plainLyrics; // Fallback if no synced lyrics exist
  final String? error;

  LyricsState({
    this.isLoading = false,
    this.syncedLyrics,
    this.plainLyrics,
    this.error,
  });
}

// --- 3. THE PROVIDER ---
final lyricsProvider = StateNotifierProvider<LyricsNotifier, LyricsState>((ref) {
  return LyricsNotifier(ref);
});

class LyricsNotifier extends StateNotifier<LyricsState> {
  final Ref ref;
  String? _lastTrackId;

  LyricsNotifier(this.ref) : super(LyricsState()) {
    // Automatically listen to the current playing song!
    ref.listen(audioHandlerProvider, (_, audioHandler) {
      audioHandler.mediaItem.listen((item) {
        if (item != null && item.id != _lastTrackId) {
          _lastTrackId = item.id;
          // 🚨 FIX: Added ?? '' to guarantee it passes a String!
          fetchLyrics(item.title, item.artist ?? '', item.duration?.inSeconds);
        }
      });
    });
  }

  Future<void> fetchLyrics(String title, String artist, int? durationSeconds) async {
    state = LyricsState(isLoading: true);

    try {
      // 1. Aggressively clean the title of YouTube junk (e.g. "Official Video", "Lyrics")
      final cleanTitle = title
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'(?i)official video|music video|lyrics|audio'), '')
          .trim();
      
      // 2. Use the SEARCH endpoint instead of GET
      final uri = Uri.parse('https://lrclib.net/api/search').replace(queryParameters: {
        'q': '$cleanTitle $artist', // Broad text search
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        if (data.isNotEmpty) {
          // 3. Find the first result that actually contains Synced Lyrics!
          final bestMatch = data.firstWhere(
            (track) => track['syncedLyrics'] != null && track['syncedLyrics'].toString().trim().isNotEmpty,
            orElse: () => data.first, // Fallback to the first result if no synced lyrics exist
          );

          final syncedText = bestMatch['syncedLyrics'] as String?;
          final plainText = bestMatch['plainLyrics'] as String?;

          if (syncedText != null && syncedText.isNotEmpty) {
            state = LyricsState(syncedLyrics: _parseLrc(syncedText));
          } else if (plainText != null && plainText.isNotEmpty) {
            state = LyricsState(plainLyrics: plainText);
          } else {
            state = LyricsState(error: "No lyrics found for this track.");
          }
        } else {
          state = LyricsState(error: "Lyrics not available.");
        }
      } else {
        state = LyricsState(error: "Failed to connect to lyrics server.");
      }
    } catch (e) {
      state = LyricsState(error: "Could not load lyrics.");
    }
  }

  // --- 4. THE LRC PARSER ---
  // Turns "[00:12.34] Hello World" into usable code
  List<LyricLine> _parseLrc(String lrc) {
    final lines = lrc.split('\n');
    final result = <LyricLine>[];
    
    // Regex to find timestamps like [01:23.45]
    final RegExp timeRegExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (var line in lines) {
      final match = timeRegExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        // Handle both 2 and 3 digit milliseconds
        String msString = match.group(3)!;
        if (msString.length == 2) msString += '0'; 
        final milliseconds = int.parse(msString);

        final text = line.replaceFirst(timeRegExp, '').trim();
        
        // Skip empty timestamp lines unless you want blank gaps
        if (text.isNotEmpty) {
          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );
          result.add(LyricLine(timestamp: timestamp, text: text));
        }
      }
    }
    return result;
  }
}