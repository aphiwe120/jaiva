import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

/// 👻 GLOWING NEURAL NODE TOGGLE - Custom Ghost DJ switch
class GhostToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const GhostToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Smart Shuffle',
  });

  @override
  State<GhostToggle> createState() => _GhostToggleState();
}

class _GhostToggleState extends State<GhostToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.value) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GhostToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.value && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggle() {
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.value ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.value
                        ? RadialGradient(
                            colors: [
                              const Color(0xFF00E5FF).withOpacity(0.8),
                              const Color(0xFF00E676).withOpacity(0.4),
                            ],
                          )
                        : null,
                    color: widget.value ? null : Colors.grey.withOpacity(0.2),
                    border: Border.all(
                      color: widget.value
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withOpacity(0.2),
                      width: 2.0,
                    ),
                    boxShadow: widget.value
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.6),
                              blurRadius: 20.0,
                              spreadRadius: 5.0,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Neural network lines (static)
                      CustomPaint(
                        size: const Size(80, 80),
                        painter: _NeuralNetworkPainter(
                          color: widget.value
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),

                      // Center node
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.value
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withOpacity(0.3),
                          boxShadow: widget.value
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.8),
                                    blurRadius: 10.0,
                                  ),
                                ]
                              : null,
                        ),
                      ),

                      // Ghost emoji for visual flair
                      Text(
                        '👻',
                        style: TextStyle(
                          fontSize: 32,
                          color: widget.value
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.label,
          style: GoogleFonts.outfit(
            fontSize: 12.0,
            fontWeight: FontWeight.w800,
            color:
                widget.value ? const Color(0xFF00E5FF) : Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.value ? 'ON' : 'OFF',
          style: GoogleFonts.outfit(
            fontSize: 10.0,
            fontWeight: FontWeight.w300,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

/// 🧠 Neural network pattern painter
class _NeuralNetworkPainter extends CustomPainter {
  final Color color;

  _NeuralNetworkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Draw connecting lines from center to outer nodes
    const nodeCount = 5;
    for (int i = 0; i < nodeCount; i++) {
      final angle = (2 * math.pi * i) / nodeCount;
      final x = center.dx + (radius * math.cos(angle));
      final y = center.dy + (radius * math.sin(angle));
      canvas.drawLine(center, Offset(x, y), paint);
    }

    // Draw outer nodes
    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < nodeCount; i++) {
      final angle = (2 * math.pi * i) / nodeCount;
      final x = center.dx + (radius * math.cos(angle));
      final y = center.dy + (radius * math.sin(angle));
      canvas.drawCircle(Offset(x, y), 3, nodePaint);
    }
  }

  @override
  bool shouldRepaint(_NeuralNetworkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
