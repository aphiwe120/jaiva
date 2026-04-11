import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:jaiva/core/player_provider.dart';

class ThemeColors {
  final Color dominant;
  final Color vibrant;
  final Color muted;

  ThemeColors({required this.dominant, required this.vibrant, required this.muted});

  factory ThemeColors.defaultColors() {
    return ThemeColors(
      dominant: const Color(0xFF121212),
      vibrant: const Color(0xFF6200EA),
      muted: const Color(0xFF424242),
    );
  }
}

final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeColors>(ThemeNotifier.new);

class ThemeNotifier extends AsyncNotifier<ThemeColors> {
  String? _lastUrl;

  @override
  FutureOr<ThemeColors> build() {
    final audioHandler = ref.watch(audioHandlerProvider);
    audioHandler.mediaItem.listen((item) {
      if (item?.artUri != null) {
        updateTheme(item!.artUri.toString());
      }
    });
    return ThemeColors.defaultColors();
  }

  Future<void> updateTheme(String imageUrl) async {
    if (imageUrl == _lastUrl) return;
    _lastUrl = imageUrl;

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 100), // Speed up calculation
        maximumColorCount: 10,
      );
      
      state = AsyncValue.data(ThemeColors(
        dominant: palette.dominantColor?.color ?? state.valueOrNull?.dominant ?? Colors.black,
        vibrant: palette.vibrantColor?.color ?? palette.dominantColor?.color ?? Colors.deepPurple,
        muted: palette.mutedColor?.color ?? palette.darkMutedColor?.color ?? Colors.grey.shade900,
      ));
    } catch (e) {
      // Retain old palette on error
    }
  }
}
