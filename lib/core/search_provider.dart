import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/core/music_repository.dart';

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepository();
});

final searchProvider = AsyncNotifierProvider<SearchNotifier, List<Song>>(() {
  return SearchNotifier();
});

final trendingProvider = AsyncNotifierProvider<TrendingNotifier, List<Song>>(() {
  return TrendingNotifier();
});

class SearchNotifier extends AsyncNotifier<List<Song>> {
  @override
  FutureOr<List<Song>> build() {
    return [];
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    
    print("[SearchNotifier] Search triggered for: '$query'");
    state = const AsyncValue.loading();
    
    try {
      final repository = ref.read(musicRepositoryProvider);
      final results = await repository.searchTracks(query);
      
      if (results.isEmpty) {
        print("[SearchNotifier] No results found for: '$query'");
        state = AsyncValue.data(results);
      } else {
        print("[SearchNotifier] Found ${results.length} results for: '$query'");
        state = AsyncValue.data(results);
      }
    } catch (e, stackTrace) {
      print('[SearchNotifier] ERROR during search: $e');
      print('[SearchNotifier] Stack trace: $stackTrace');
      
      // Check if it's an authentication error
      if (e.toString().contains('Authentication') || 
          e.toString().contains('401') || 
          e.toString().contains('403')) {
        print('[SearchNotifier] Authentication error detected - using guest mode fallback');
        state = AsyncValue.error(
          'Authentication required. Please check your internet connection and try again.',
          stackTrace,
        );
      } else {
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }
}

class TrendingNotifier extends AsyncNotifier<List<Song>> {
  @override
  FutureOr<List<Song>> build() async {
    // Load trending data on init
    return _fetchTrending();
  }

  Future<List<Song>> _fetchTrending() async {
    print("[TrendingNotifier] ════════════════════════════════════════");
    print("[TrendingNotifier] Fetching trending charts");
    print("[TrendingNotifier] ════════════════════════════════════════");
    try {
      final repository = ref.read(musicRepositoryProvider);
      final results = await repository.getCharts();
      
      if (results.isNotEmpty) {
        print("[TrendingNotifier] ✅ Successfully loaded ${results.length} songs");
        return results;
      } else {
        print("[TrendingNotifier] ⚠️  getCharts() returned empty");
        return [];
      }
    } catch (e, stackTrace) {
      print("[TrendingNotifier] ❌ ERROR: $e");
      print("[TrendingNotifier] Stack: $stackTrace");
      throw e; // Re-throw to let AsyncValue handle it
    }
  }

  Future<void> refresh() async {
    print("[TrendingNotifier] Refresh triggered");
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _fetchTrending());
  }
}
