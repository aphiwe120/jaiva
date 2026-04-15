import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

/// ☄️ RADAR SCAN ANIMATION - Expanding concentric circles for discovery
class RadarScan extends StatefulWidget {
  final Color color;
  final Duration duration;

  const RadarScan({
    super.key,
    this.color = const Color(0xFF06B6D4),
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<RadarScan> createState() => _RadarScanState();
}

class _RadarScanState extends State<RadarScan>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadarPainter(
            progress: _controller.value,
            color: widget.color,
          ),
          child: Container(),
        );
      },
    );
  }
}

/// Paints expanding concentric circles
class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw multiple expanding circles (wave effect)
    for (int i = 0; i < 4; i++) {
      final delay = i * 0.25;
      final adjustedProgress = (progress + delay) % 1.0;
      
      final radius = maxRadius * adjustedProgress;
      final opacity = 1.0 - adjustedProgress;

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);

      // Draw dashes on circles for visual interest
      final dashCount = 12;
      for (int j = 0; j < dashCount; j++) {
        final angle = (2 * math.pi * j) / dashCount;
        final innerRadius = radius - 10;
        final outerRadius = radius + 10;

        final x1 = center.dx + (innerRadius * math.cos(angle));
        final y1 = center.dy + (innerRadius * math.sin(angle));
        final x2 = center.dx + (outerRadius * math.cos(angle));
        final y2 = center.dy + (outerRadius * math.sin(angle));

        final dashPaint = Paint()
          ..color = color.withOpacity(opacity * 0.4)
          ..strokeWidth = 1.0;

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), dashPaint);
      }
    }

    // Draw center dot
    final centerPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6, centerPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// 🔥 GLOBAL DISCOVERY BADGE with neon glow
class DiscoveryBadge extends StatelessWidget {
  final String label;
  final Color glowColor;

  const DiscoveryBadge({
    super.key,
    this.label = 'VAULT DISCOVERY',
    this.glowColor = const Color(0xFF06B6D4),
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 14.0,
        fontWeight: FontWeight.w800,
        color: glowColor,
        letterSpacing: 1.5,
        shadows: [
          Shadow(
            color: glowColor.withOpacity(0.8),
            blurRadius: 20.0,
            offset: Offset.zero,
          ),
          Shadow(
            color: glowColor.withOpacity(0.4),
            blurRadius: 40.0,
            offset: Offset.zero,
          ),
        ],
      ),
    );
  }
}
