import 'package:flutter/material.dart';
import 'package:keywordschat/widgets/chart_painters.dart';

/// A card that displays a metric with an optional sparkline chart
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<double>? sparklineData;
  final bool showSparklinePlaceholder;
  final bool invertSparkline;
  final String? tooltip;
  final bool compact;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.sparklineData,
    this.showSparklinePlaceholder = false,
    this.invertSparkline = false,
    this.tooltip,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasSparkline = sparklineData != null && sparklineData!.length >= 2;
    final showPlaceholder = !hasSparkline && showSparklinePlaceholder;
    
    final cardContent = Card(
      child: Padding(
        padding: compact ? const EdgeInsets.all(12.0) : const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: compact ? 16 : 20, color: color),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: compact ? 18 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasSparkline || showPlaceholder) ...[
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: SizedBox(
                      height: compact ? 24 : 30,
                      child: hasSparkline
                          ? CustomPaint(
                              painter: SparklinePainter(
                                sparklineData!,
                                color.withOpacity(0.6),
                                invertY: invertSparkline, // Support inverted sparklines (for rankings where lower is better)
                              ),
                            )
                          : CustomPaint(
                              painter: NoDataSparklinePainter(
                                color.withOpacity(0.3),
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    
    // Wrap with tooltip if provided
    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        preferBelow: false,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
        ),
        waitDuration: const Duration(milliseconds: 500),
        child: cardContent,
      );
    }
    
    return cardContent;
  }
}

