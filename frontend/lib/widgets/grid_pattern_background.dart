import 'package:flutter/material.dart';

/// Subtle grid pattern background widget
/// Matches the OG image aesthetic - adds visual depth without distraction
class GridPatternBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  final Color? patternColor;

  const GridPatternBackground({
    super.key,
    required this.child,
    this.opacity = 0.03,
    this.patternColor,
  });

  @override
  Widget build(BuildContext context) {
    // Use theme color or default to cyan/turquoise
    final color = patternColor ?? 
        Theme.of(context).colorScheme.secondary.withOpacity(opacity);
    
    return Stack(
      children: [
        // Grid pattern background
        Positioned.fill(
          child: CustomPaint(
            painter: GridPatternPainter(
              color: color,
            ),
          ),
        ),
        // Content on top
        child,
      ],
    );
  }
}

/// Custom painter for grid pattern
/// Matches the OG image style - very fine 2px lines every 4px creating subtle grid
class GridPatternPainter extends CustomPainter {
  final Color color;

  GridPatternPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw thin grid lines every 4px (matching OG image: 2px line, 2px gap)
    // Vertical lines
    for (double x = 2; x < size.width; x += 4) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (double y = 2; y < size.height; y += 4) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

