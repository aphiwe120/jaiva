import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 🎵 ROTATING BPM RING - Paints a rotating ring synchronized with BPM
class BPMRing extends CustomPainter {
  final double rotationAngle;
  final double bpm;
  final Color color;

  BPMRing({
    required this.rotationAngle,
    required this.bpm,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;

    // Draw rotating ring
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawCircle(center, radius, paint);

    // Draw dashes around ring for visual effect
    final dashCount = 12;
    for (int i = 0; i < dashCount; i++) {
      final angle = (2 * math.pi * i) / dashCount;
      final x1 = center.dx + (radius * math.cos(angle));
      final y1 = center.dy + (radius * math.sin(angle));
      final x2 = center.dx + ((radius + 15) * math.cos(angle));
      final y2 = center.dy + ((radius + 15) * math.sin(angle));
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(BPMRing oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.bpm != bpm ||
        oldDelegate.color != color;
  }
}

/// 🫀 DNA CIRCULAR DISK with rotating BPM ring and breath effect
class DNACoreDisk extends StatefulWidget {
  final String imagePath;
  final bool isNetworkImage;
  final double bpm;
  final double auraColor;
  final bool isPlaying;

  const DNACoreDisk({
    super.key,
    required this.imagePath,
    this.isNetworkImage = false,
    required this.bpm,
    required this.auraColor,
    required this.isPlaying,
  });

  @override
  State<DNACoreDisk> createState() => _DNACoreDiskState();
}

class _DNACoreDiskState extends State<DNACoreDisk>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _breathAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    // Breath effect - pulse up and down
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Rotation effect - continuous spin
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(DNACoreDisk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate ring speed based on BPM (faster BPM = faster rotation)
    final ringSpeed = widget.bpm / 120.0; // Normalize to baseline BPM

    return AnimatedBuilder(
      animation: Listenable.merge([_breathAnimation, _rotationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _breathAnimation.value,
          child: SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 🎨 Outer rotating BPM ring
                CustomPaint(
                  size: const Size(300, 300),
                  painter: BPMRing(
                    rotationAngle: _rotationAnimation.value * ringSpeed,
                    bpm: widget.bpm,
                    color: _getAuraColor(widget.auraColor),
                  ),
                ),

                // 🎵 Circular album art disk
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getAuraColor(widget.auraColor).withOpacity(0.4),
                        blurRadius: 30.0,
                        spreadRadius: 5.0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.isNetworkImage
                        ? Image.network(
                            widget.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.music_note,
                                  size: 80, color: Colors.white),
                            ),
                          )
                        : Image.asset(
                            widget.imagePath,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),

                // 🔵 Center dot
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getAuraColor(widget.auraColor),
                    boxShadow: [
                      BoxShadow(
                        color: _getAuraColor(widget.auraColor).withOpacity(0.6),
                        blurRadius: 10.0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getAuraColor(double auraValue) {
    if (auraValue < 0.3) {
      return const Color(0xFF00E676); // Neon Emerald Green - Chill
    } else if (auraValue < 0.7) {
      return const Color(0xFFFFAB00); // Amber/Gold - Mid-range
    } else {
      return const Color(0xFF00E5FF); // Electric Cyan - High Energy
    }
  }
}
