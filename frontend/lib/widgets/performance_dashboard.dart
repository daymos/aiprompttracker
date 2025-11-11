import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PerformanceDashboard extends StatelessWidget {
  final List<Map<String, dynamic>> metrics;
  final String url;

  const PerformanceDashboard({
    super.key,
    required this.metrics,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    // Find overall performance score
    final overallMetric = metrics.firstWhere(
      (m) => m['metric_name'] == 'Performance Score',
      orElse: () => {'score': 0, 'rating': 'N/A'},
    );
    final overallScore = (overallMetric['score'] ?? 0).toDouble();

    // Get Core Web Vitals metrics (excluding overall score)
    final coreMetrics = metrics.where((m) => m['metric_name'] != 'Performance Score').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Performance Analysis',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            url,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),

          // Overall Score - Large circular gauge
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      PieChart(
                        PieChartData(
                          startDegreeOffset: 270,
                          sectionsSpace: 0,
                          centerSpaceRadius: 70,
                          sections: [
                            PieChartSectionData(
                              value: overallScore,
                              color: _getScoreColor(overallScore),
                              radius: 30,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: (100 - overallScore).toDouble(),
                              color: Colors.grey[800],
                              radius: 30,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                      // Score text in center
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${overallScore.toInt()}',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(overallScore),
                            ),
                          ),
                          Text(
                            overallMetric['rating']?.toString().toUpperCase() ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400],
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Overall Performance Score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Core Web Vitals - Individual metrics
          Text(
            'Core Web Vitals & Metrics',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // Grid of metric cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: coreMetrics.map((metric) {
              return _buildMetricCard(metric);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
    final score = (metric['score'] ?? 0).toDouble();
    final metricName = metric['metric_name']?.toString() ?? 'N/A';
    final value = metric['value']?.toString() ?? 'N/A';
    final description = metric['description']?.toString() ?? '';
    final rating = metric['rating']?.toString() ?? 'N/A';

    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getScoreColor(score).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric name and value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metricName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(score),
                      ),
                    ),
                  ],
                ),
              ),
              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getScoreColor(score).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${score.toInt()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(score),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
            ),
          ),
          const SizedBox(height: 8),

          // Rating
          Row(
            children: [
              Icon(
                _getRatingIcon(rating),
                size: 14,
                color: _getScoreColor(score),
              ),
              const SizedBox(width: 4),
              Text(
                rating.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getScoreColor(score),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  IconData _getRatingIcon(String rating) {
    switch (rating.toLowerCase()) {
      case 'good':
        return Icons.check_circle;
      case 'needs improvement':
        return Icons.warning;
      case 'poor':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }
}

