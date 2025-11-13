import 'package:flutter/material.dart';

/// Widget showing trend with arrow and percentage change
class TrendIndicator extends StatelessWidget {
  final double trend;
  final bool inverseTrend;

  const TrendIndicator({
    super.key,
    required this.trend,
    this.inverseTrend = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = inverseTrend ? trend < 0 : trend > 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            '${trend.abs().toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

