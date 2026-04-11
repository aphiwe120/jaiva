import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/core/search_provider.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/add_to_playlist_sheet.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/jaiva_bottom_nav.dart';
import 'package:jaiva/ui/widgets/song_options_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 🚨 FIX: Wrapped the column area in Positioned.fill to prevent the crash!
          Positioned.fill(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Text("Search", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ),
                  
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: "What do you want to listen to?",
                          hintStyle: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
                          prefixIcon: Icon(Icons.search, size: 28, color: Colors.black87),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (query) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 500), () {
                            if (query.trim().isNotEmpty) {
                              ref.read(searchProvider.notifier).search(query.trim());
                            }
                            setState(() {}); // Trigger rebuild to show/hide results
                          });
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Results List
                  Expanded(
                    child: _searchController.text.isEmpty
                        ? const Center(child: Text("Browse categories coming soon", style: TextStyle(color: Colors.grey)))
                        : searchQuery.when(
                            data: (songs) => ListView.builder(
                              itemCount: songs.length,
                              padding: const EdgeInsets.only(bottom: 120),
                              itemBuilder: (context, index) {
                                final song = songs[index];
                                return ListTile(
                                  leading: CachedNetworkImage(imageUrl: song.thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover),
                                  title: Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), maxLines: 1),
                                  subtitle: Text(song.artist, style: const TextStyle(color: Colors.grey)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                                    onPressed: () {
                                      final songToAdd = Song(
                                        id: song.id,
                                        title: song.title,
                                        artist: song.artist,
                                        thumbnailUrl: song.thumbnailUrl,
                                      );
                                      // 🚨 OPEN THE NEW OPTIONS SHEET INSTEAD!
                                      SongOptionsSheet.show(context, songToAdd);
                                    },
                                  ),
                                  onTap: () {
                                    _focusNode.unfocus();
                                    ref.read(audioHandlerProvider).playMediaItem(MediaItem(
                                      id: song.id, title: song.title, artist: song.artist, artUri: Uri.parse(song.thumbnailUrl),
                                    ));
                                  },
                                );
                              },
                            ),
                            loading: () => const Center(child: CircularProgressIndicator(color: Colors.green)),
                            error: (e, _) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
                          ),
                  ),
                ],
              ),
            ),
          ),
          
          // --- MINI PLAYER ---
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: const JaivaBottomNav(currentIndex: 1),
    );
  }
}