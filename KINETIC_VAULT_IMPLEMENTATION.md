# 🎨 KINETIC VAULT DESIGN SYSTEM - Implementation Guide

## ✅ COMPLETED Phase 1: Design Foundation

### 1. Theme & Core Utilities (`lib/theme/kinetic_vault_theme.dart`)
- **KineticVaultTheme**: Central color and styling system
  - `getAuraColor(auraValue)`: Dynamically returns Deep Purple (<0.3), Electric Pink (0.3-0.7), or Cyan (>0.7)
  - `glassBorder`: White border at 0.1 opacity for all glass cards
  - `glassBlur`: ImageFilter with 20.0 sigma for glassmorphism effect
  - `neonGlow()`: Shadow effects for neon text labels

- **AuraOrb**: Positioned animated background orb
  - Gradient circle with dynamic color based on DNA
  - BlurMask effect for glassmorphism
  - Size-scalable for different screens

- **GlassCard**: Reusable container with glassmorphism
  - BorderRadius customization
  - BackdropFilter blur at 20.0
  - Semi-transparent background with border

- **GenreBadge**: Frosted glass badges for genre labels
  - Takes genre string and accent color
  - Renders in ALL CAPS with letter-spacing

### 2. DNA Core Disk (`lib/ui/widgets/dna_core_disk.dart`)
- **BPMRing**: CustomPainter for rotating ring
  - Speed synchronized with BPM (faster = more rotations)
  - 12 dashes around circumference for visual effect
  - Color from Aura determined by auraColor param

- **DNACoreDisk**: Stateful widget with animations
  - **Breath Effect**: Scale animation (1.0 → 1.1 → 1.0) over 4 seconds
  - **Rotation**: Ring rotates based on BPM speed
  - **Circular Album Art**: ClipOval with BoxShadow glow
  - **Center Dot**: Glowing accent sphere
  - Auto-animates when `isPlaying = true`

### 3. Ghost DJ Toggle (`lib/ui/widgets/ghost_toggle.dart`)
- **GhostToggle**: Custom neural node switch
  - When ON: Emits pink gradient, glows, and pulses (1500ms cycle)
  - When OFF: Dim grey wireframe, no glow
  - Visual elements: Neural network lines, center node, 👻 emoji
  - Custom callback `onChanged(bool)` for state management

- **_NeuralNetworkPainter**: CustomPainter for brain-like pattern
  - Center node with 5 connecting radial lines
  - 5 outer nodes at circumference

### 4. Radar Scan (`lib/ui/widgets/radar_scan.dart`)
- **RadarScan**: Expanding concentric circle animation
  - 4 waves with staggered delay for continuous effect
  - Progress-based opacity fade
  - 12 dashes per circle for detail
  - 3-second animation cycle (customizable)

- **DiscoveryBadge**: Neon glow text
  - "VAULT DISCOVERY" label with shadow glow
  - Cyan color by default, customizable

## 🎯 NEXT STEPS: Screen Integration

### Home Screen (`lib/ui/screens/home_screen.dart`)
```dart
// 1. Add AuraOrb to Stack background
AuraOrb(
  auraValue: currentSong?.aura ?? 0.5,
  size: 400.0,
),

// 2. Convert ListView to MasonryGridView (flutter_staggered_grid_view package)
// 3. For each song tile, add responsive height based on BPM:
//    - BPM > 120: crossAxisCellCount: tall
//    - BPM < 90: wide
// 4. Overlay GenreBadge in corner of each tile
```

### Player Screen (`lib/ui/screens/now_playing.dart`)
```dart
// 1. Replace album art with DNACoreDisk
DNACoreDisk(
  imagePath: mediaItem.artUri.toString(),
  bpm: currentSongDNA.bpm,
  auraColor: currentSongDNA.aura,
  isPlaying: _player.playing,
),

// 2. Add GhostToggle below the disk
GhostToggle(
  value: isSmartShuffleEnabled,
  onChanged: (newValue) {
    ref.read(audioHandlerProvider).smartShuffleToggle(newValue);
  },
  label: 'Smart Shuffle',
),

// 3. Wrap controls in GlassCard
GlassCard(
  child: Row(
    children: [
      // Play/Pause as floating glass circle
      // Forward/Back buttons
    ],
  ),
)
```

### Discovery Screen (`lib/ui/screens/discovery_screen.dart`)
```dart
// 1. When in Global Discovery mode, add RadarScan background
Stack(
  children: [
    // Background
    if (isDiscoveryMode) ...[
      Positioned.fill(
        child: SizedBox(
          height: 300,
          child: RadarScan(
            color: Color(0xFF06B6D4),
          ),
        ),
      ),
    ],
    
    // Recommended track card with DiscoveryBadge
    GlassCard(
      child: Column(
        children: [
          DiscoveryBadge(label: 'VAULT DISCOVERY'),
          // Track info
        ],
      ),
    ),
  ],
)
```

### Vault Screen (`lib/ui/screens/vault_screen.dart`)
```dart
// Convert to MasonryGridView with:
// - GenreBadge overlay for each song
// - Responsive tile sizing by BPM
// - GlassCard wrapper for each tile
```

## 📦 Required Package Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_staggered_grid_view: ^0.7.0
  # Already have: flutter, audio_service, just_audio, etc.
```

## 🎬 Animation Specs

| Component | Duration | Curve | Trigger |
|-----------|----------|-------|---------|
| Breath effect (Disk pulse) | 4s | easeInOut | Playing |
| BPM ring rotation | Based on BPM | linear | Always |
| Ghost pulse | 1.5s | easeInOut | Ghost ON |
| Radar scan | 3s | linear | Discovery mode |

## 🎨 Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| Deep Purple | #7C3AED | Aura < 0.3, Primary |
| Electric Pink | #EC4899 | Aura 0.3-0.7, Ghost on, Secondary |
| Cyan/Mint | #06B6D4 | Aura > 0.7, Discovery |
| Dark BG | #0F0F0F | Scaffold background |
| Card BG | #1A1A1A | Glass card surface |
| Glass White | #FFFFFF (10% opacity) | Borders, subtle overlays |

## 🔧 Performance Tips
1. Use `const` constructors in KineticVaultTheme
2. Limit custom painters to only visible widgets
3. Use `AnimatedBuilder` instead of `setState` for smooth 60fps
4. Cache image assets before DNACoreDisk animation starts
5. Stop animations when widget hidden (dispose properly)

## 📝 State Management
Connect *currentSongDNA* from BackgroundAudioHandler provider:
```dart
final currentDNA = ref.watch(playerProvider).currentSongDNA;

DNACoreDisk(
  auraColor: currentDNA?.aura ?? 0.5,
  bpm: currentDNA?.bpm ?? 120.0,
  // ...
)
```

---

✨ **Kinetic Vault is now ready for screen integration!** Start with player_screen.dart for the DNA Core Disk.
