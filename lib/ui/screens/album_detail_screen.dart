import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jaiva/core/player_provider.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';
import 'package:jaiva/models/song.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  final Song album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  final YoutubeExplode _yt = YoutubeExplode();
  List<MediaItem> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlbumTracks();
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  Future<void> _fetchAlbumTracks() async {
    try {
      var playlist = await _yt.playlists.get(widget.album.id);
      List<MediaItem> fetchedTracks = [];

      await for (var video in _yt.playlists.getVideos(playlist.id)) {
        fetchedTracks.add(
          MediaItem(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            duration: video.duration,
            artUri: Uri.parse(video.thumbnails.highResUrl),
            extras: {'albumTitle': playlist.title}, 
          ),
        );
      }

      if (mounted) {
        setState(() {
          _tracks = fetchedTracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching album: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // 🎨 Background Aura
          const AuraOrb(auraValue: 0.7, size: 500.0),
          
          CustomScrollView(
            slivers: [
              // 🌄 Hero Image Header
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                backgroundColor: const Color(0xFF0F0F0F).withOpacity(0.9),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.album.thumbnailUrl,
                        fit: BoxFit.cover,
                      ),
                      // Gradient to blend image into background
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0F0F0F).withOpacity(0.8),
                              const Color(0xFF0F0F0F),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 📜 Album Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.album.title,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.album.artist,
                        style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 24),
                      
                      // Play All Button
                      if (!_isLoading && _tracks.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 30),
                            label: Text("PLAY ALBUM", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            onPressed: () {
                              ref.read(audioHandlerProvider).playPlaylist(_tracks, startIndex: 0);
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // 🎵 The Tracklist
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
                )
              else if (_tracks.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Text("No tracks found.", style: GoogleFonts.outfit(color: Colors.white54))),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _tracks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Text(
                          "${index + 1}",
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        title: Text(
                          track.title,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artist ?? 'Unknown',
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.more_vert, color: Colors.white54),
                        onTap: () {
                          // 🚀 THE UPGRADE: Pass the whole album, but start at the clicked index!
                          ref.read(audioHandlerProvider).playPlaylist(_tracks, startIndex: index);
                        },
                      );
                    },
                    childCount: _tracks.length,
                  ),
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding for mini-player
            ],
          ),
        ],
      ),
    );
  }
}