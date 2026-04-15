import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 KINETIC VAULT DESIGN TOKENS - DARK TECH THEME
class KineticVaultTheme {
  // 🎨 Dynamic Aura Colors based on DNA Aura value (0.0 - 1.0) - Dark Tech Scheme
  static Color getAuraColor(double auraValue) {
    if (auraValue < 0.3) {
      // Chill/Dark: Neon Emerald Green
      return const Color(0xFF00E676);
    } else if (auraValue < 0.7) {
      // Mid-range/Default: Amber/Gold
      return const Color(0xFFFFAB00);
    } else {
      // High Energy: Electric Cyan/Blue
      return const Color(0xFF00E5FF);
    }
  }

  // Base Glassmorphism border
  static BoxBorder get glassBorder => Border.all(
    color: Colors.white.withOpacity(0.1),
    width: 1.0,
  );

  // Glassmorphism backdrop filter
  static ImageFilter get glassBlur => ImageFilter.blur(
    sigmaX: 20.0,
    sigmaY: 20.0,
  );

  // Neon glow effect for text
  static List<Shadow> neonGlow(Color color) => [
    Shadow(
      color: color.withOpacity(0.8),
      blurRadius: 20.0,
      offset: Offset.zero,
    ),
    Shadow(
      color: color.withOpacity(0.4),
      blurRadius: 40.0,
      offset: Offset.zero,
    ),
  ];
}

/// 🔵 AURA ORB - Dynamic animated background
class AuraOrb extends StatelessWidget {
  final double auraValue;
  final double size;
  
  const AuraOrb({
    super.key,
    required this.auraValue,
    this.size = 400.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = KineticVaultTheme.getAuraColor(auraValue);
    
    return Positioned(
      top: -size / 2,
      right: -size / 3,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.5),
              color.withOpacity(0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 60.0,
              spreadRadius: 20.0,
            ),
          ],
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
          child: Container(),
        ),
      ),
    );
  }
}

/// 🔹 GLASSMORPHISM CARD - Reusable glass-effect container
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final double borderRadius;
  
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.backgroundColor,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: KineticVaultTheme.glassBlur,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.05),
            border: KineticVaultTheme.glassBorder,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 🏷️ GENRE BADGE - Frosted glass with genre text
class GenreBadge extends StatelessWidget {
  final String genre;
  final Color accentColor;
  
  const GenreBadge({
    super.key,
    required this.genre,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      backgroundColor: Colors.black.withOpacity(0.5),
      borderRadius: 8.0,
      child: Text(
        genre.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 10.0,
          fontWeight: FontWeight.w800,
          color: accentColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// ThemeData for Kinetic Vault
ThemeData get kineticVaultThemeData {
  return ThemeData.dark().copyWith(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    textTheme: GoogleFonts.outfitTextTheme(
      ThemeData.dark().textTheme,
    ),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF00E5FF),
      secondary: const Color(0xFF00E676),
      tertiary: const Color(0xFFFFAB00),
      surface: const Color(0xFF0A0A12),
      background: const Color(0xFF0F0F0F),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
