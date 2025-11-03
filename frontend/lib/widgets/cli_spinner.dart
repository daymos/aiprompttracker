import 'package:flutter/material.dart';
import 'dart:async';

/// A CLI-style animated spinner with 4 vertical dots
/// Similar to terminal loading indicators
class CliSpinner extends StatefulWidget {
  final Color? color;
  final double size;
  final Duration speed;

  const CliSpinner({
    super.key,
    this.color,
    this.size = 16,
    this.speed = const Duration(milliseconds: 80),
  });

  @override
  State<CliSpinner> createState() => _CliSpinnerState();
}

class _CliSpinnerState extends State<CliSpinner> {
  // Vertical 4-dot spinner frames - creates a smooth wave effect
  static const List<String> _frames = [
    '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷'
  ];
  
  int _currentFrame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    _timer = Timer.periodic(widget.speed, (timer) {
      if (mounted) {
        setState(() {
          _currentFrame = (_currentFrame + 1) % _frames.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? Theme.of(context).colorScheme.primary;
    
    return Text(
      _frames[_currentFrame],
      style: TextStyle(
        fontSize: widget.size,
        color: effectiveColor,
        fontWeight: FontWeight.bold,
        height: 1.0,
      ),
    );
  }
}

/// A more elaborate thinking indicator with animated dots
class ThinkingIndicator extends StatefulWidget {
  final String text;
  final Color? color;
  final double fontSize;

  const ThinkingIndicator({
    super.key,
    this.text = 'Thinking',
    this.color,
    this.fontSize = 14,
  });

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator> {
  int _dotCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    final dots = '.' * _dotCount;
    
    return Text(
      '${widget.text}$dots',
      style: TextStyle(
        fontSize: widget.fontSize,
        color: effectiveColor,
      ),
    );
  }
}

