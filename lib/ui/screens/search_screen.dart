import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jaiva/core/search_provider.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/ui/widgets/add_to_playlist_sheet.dart';
import 'package:jaiva/models/song.dart';
import 'package:jaiva/ui/screens/album_detail_screen.dart';
import 'package:jaiva/ui/widgets/mini_player.dart';
import 'package:jaiva/ui/widgets/jaiva_bottom_nav.dart';
import 'package:jaiva/ui/widgets/song_options_sheet.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';
import 'package:jaiva/ui/widgets/kinetic_song_tile.dart';

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
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // 🎨 Kinetic Vault: Aura Orb Background
          const AuraOrb(
            auraValue: 0.6, // Cyan/Emerald for Dark Tech
            size: 400.0,
          ),

          Positioned.fill(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Text(
                      "Search",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  
                  // 🎧 Search Bar with GlassCard
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      borderRadius: 12.0,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                        decoration: InputDecoration(
                          hintText: "What do you want to listen to?",
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white54,
                            fontWeight: FontWeight.w300,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 24, color: Colors.white70),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (query) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 500), () {
                            if (query.trim().isNotEmpty) {
                              ref.read(searchProvider.notifier).search(query.trim());
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Results Grid
                  Expanded(
                    child: _searchController.text.isEmpty
                        ? Center(
                            child: Text(
                              "Browse categories coming soon",
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          )
                        : searchQuery.when(
                            data: (songs) => GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16.0,
                                crossAxisSpacing: 16.0,
                                childAspectRatio: 0.75, // Keeps the cards tall and sleek!
                              ),
                              padding: const EdgeInsets.all(16.0).copyWith(bottom: 140),
                              itemCount: songs.length,
                              itemBuilder: (context, index) {
                                final song = songs[index];
                                
                                // 🧠 SMART ALBUM DETECTION: YouTube Video IDs are exactly 11 chars. 
                                // Album/Playlist IDs (like OLAK5uy...) are much longer.
                                final bool isAlbum = song.id.length > 11;

                                return KineticSongTile(
                                  key: ValueKey(song.id), 
                                  song: Song(
                                    id: song.id,
                                    title: song.title,
                                    artist: song.artist,
                                    thumbnailUrl: song.thumbnailUrl,
                                    // 👇 Visual indicator injected into the UI!
                                    genre: isAlbum ? '📀 FULL ALBUM' : '🎵 TRACK',
                                  ),
                                  bpm: 120.0,
                                  genre: isAlbum ? '📀 ALBUM' : 'Search',
                                  onTap: () {
                                    _focusNode.unfocus();
                                    
                                    if (isAlbum) {
                                      // 🚀 NEW: Navigate to the beautiful Album Detail Screen
                                      final albumData = Song(
                                        id: song.id,
                                        title: song.title,
                                        artist: song.artist,
                                        thumbnailUrl: song.thumbnailUrl,
                                        genre: 'Album',
                                      );
                                      
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AlbumDetailScreen(album: albumData),
                                        ),
                                      );
                                      
                                    } else {
                                      // 1. Send normal track to normal player logic
                                      ref.read(audioHandlerProvider).playMediaItem(MediaItem(
                                        id: song.id,
                                        title: song.title,
                                        artist: song.artist,
                                        artUri: Uri.parse(song.thumbnailUrl),
                                      ));
                                    }
                                  },
                                  onLongPress: () {
                                    final songToAdd = Song(
                                      id: song.id,
                                      title: song.title,
                                      artist: song.artist,
                                      thumbnailUrl: song.thumbnailUrl,
                                      genre: isAlbum ? 'Album' : 'Search',
                                    );
                                    SongOptionsSheet.show(context, songToAdd);
                                  },
                                );
                              },
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(color: Color(0xFF00E676)), 
                            ),
                            error: (e, _) => Center(
                              child: Text(
                                "Error: $e",
                                style: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
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