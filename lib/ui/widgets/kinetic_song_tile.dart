import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';
import 'package:jaiva/models/song.dart';

/// 🎵 KINETIC VAULT SONG TILE - Reusable across all screens
class KineticSongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double bpm;
  final String genre;
  final bool isSelected;

  const KineticSongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    this.bpm = 120.0,
    this.genre = 'Unknown',
    this.isSelected = false,
  });

  /// Determine if tile should be tall (high BPM) or wide (low BPM)
  /// Tall: BPM > 120, Wide: BPM < 90, Medium: in between
  int get aspectRatioMultiplier {
    if (bpm > 120) return 1; // tall (1:1 becomes stacked)
    if (bpm < 90) return 2; // wide (2:1)
    return 1; // medium
  }

  /// Get aura color from BPM range - Dark Tech Scheme
  Color get auraColor {
    if (bpm < 100) return const Color(0xFF00E676); // Emerald Green - slow/chill
    if (bpm < 130) return const Color(0xFFFFAB00); // Amber/Gold - medium
    return const Color(0xFF00E5FF); // Electric Cyan - fast/energetic
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 16.0,
        backgroundColor: isSelected
            ? auraColor.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 🎨 Album Art Background
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: CachedNetworkImage(
                imageUrl: song.thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.music_note, size: 40, color: Colors.white),
                ),
              ),
            ),

            // 🌓 Dark Gradient Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),

            // 📋 Song Information
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🏷️ Genre Badge (top-right)
                  Align(
                    alignment: Alignment.topRight,
                    child: GenreBadge(
                      genre: genre,
                      accentColor: auraColor,
                    ),
                  ),

                  // Song details (bottom)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: GoogleFonts.outfit(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: GoogleFonts.outfit(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w300,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // BPM indicator
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: auraColor,
                              boxShadow: [
                                BoxShadow(
                                  color: auraColor.withOpacity(0.6),
                                  blurRadius: 4.0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${bpm.toStringAsFixed(0)} BPM',
                            style: GoogleFonts.outfit(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w300,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ✨ Selection Indicator
            if (isSelected)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: auraColor,
                    boxShadow: [
                      BoxShadow(
                        color: auraColor.withOpacity(0.6),
                        blurRadius: 8.0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
