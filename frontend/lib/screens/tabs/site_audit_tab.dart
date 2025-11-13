import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../widgets/expandable_audit_item.dart';
import '../../widgets/trend_indicator.dart';
import '../../utils/color_helpers.dart';
import '../chat_screen.dart';

/// Tab for displaying site audit history and technical SEO metrics
class SiteAuditTab extends StatefulWidget {
  final Project project;
  final TextEditingController messageController;
  final VoidCallback onSwitchToChatView;
  final Function(ProjectTab) onTabChanged;

  const SiteAuditTab({
    super.key,
    required this.project,
    required this.messageController,
    required this.onSwitchToChatView,
    required this.onTabChanged,
  });

  @override
  State<SiteAuditTab> createState() => _SiteAuditTabState();
}

class _SiteAuditTabState extends State<SiteAuditTab> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return FutureBuilder<Map<String, dynamic>>(
      future: authProvider.apiService.get('/chat/project/${widget.project.id}/technical-audits'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Error loading audit history',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }
        
        final data = snapshot.data;
        final audits = data?['audits'] as List? ?? [];
        
        if (audits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'No Site Audits Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Run a site audit to track performance, SEO, and crawlability over time',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onTabChanged(ProjectTab.overview);
                    widget.onSwitchToChatView();
                    widget.messageController.text = 'run a site audit for ${widget.project.targetUrl}';
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run First Audit'),
                ),
              ],
            ),
          );
        }
        
        // Get latest audit
        final latestAudit = audits.first;
        final performanceScore = latestAudit['performance_score'] ?? 0;
        final seoIssues = latestAudit['seo_issues_count'] ?? 0;
        final seoIssuesHigh = latestAudit['seo_issues_high'] ?? 0;
        final seoIssuesMedium = latestAudit['seo_issues_medium'] ?? 0;
        final seoIssuesLow = latestAudit['seo_issues_low'] ?? 0;
        final botsAllowed = latestAudit['bots_allowed'] ?? 0;
        final botsBlocked = latestAudit['bots_blocked'] ?? 0;
        final botsChecked = latestAudit['bots_checked'] ?? 0;
        
        // Calculate trends
        final perfTrend = latestAudit['performance_trend'];
        final seoTrend = latestAudit['seo_issues_trend'];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with latest audit info
              Row(
                children: [
                  const Icon(Icons.health_and_safety, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Site Audit',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${audits.length} audit${audits.length == 1 ? '' : 's'} performed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onSwitchToChatView();
                      widget.messageController.text = 'run a site audit for ${widget.project.targetUrl}';
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Run New Audit'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Latest Metrics Summary - Enhanced with more detail
              Row(
                children: [
                  Expanded(
                    child: _buildEnhancedPerformanceCard(
                      latestAudit, 
                      perfTrend,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildEnhancedSEOIssuesCard(
                      seoIssues,
                      seoIssuesHigh,
                      seoIssuesMedium,
                      seoIssuesLow,
                      seoTrend,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildEnhancedBotAccessCard(
                      botsAllowed,
                      botsBlocked,
                      botsChecked,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Performance Score Chart
              if (audits.length > 1) ...[
                const Text(
                  'Performance Score History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildAuditPerformanceChart(audits),
                const SizedBox(height: 32),
              ],
              
              // Audit History List
              const Text(
                'Audit History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...audits.map((audit) => _buildAuditHistoryItem(audit)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthMetricCard(String title, String value, IconData icon, Color color, {double? trend, bool inverseTrend = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 8),
                TrendIndicator(trend: trend, inverseTrend: inverseTrend),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditPerformanceChart(List audits) {
    // Reverse to show oldest first (left to right)
    final reversed = audits.reversed.toList();
    final scores = reversed.map((a) => (a['performance_score'] ?? 0).toDouble()).toList();
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[800]!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < reversed.length) {
                    final audit = reversed[value.toInt()];
                    final date = DateTime.parse(audit['created_at']);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${date.month}/${date.day}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (reversed.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                scores.length,
                (index) => FlSpot(index.toDouble(), scores[index]),
              ),
              isCurved: true,
              color: Theme.of(context).primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: Theme.of(context).primaryColor,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditHistoryItem(Map<String, dynamic> audit) {
    return ExpandableAuditHistoryItem(audit: audit, getScoreColor: ColorHelpers.getScoreColor);
  }

  Widget _buildEnhancedPerformanceCard(Map<String, dynamic> audit, double? trend) {
    final performanceScore = audit['performance_score'] ?? 0;
    final lcpValue = audit['lcp_value'] ?? 'N/A';
    final fcpValue = audit['fcp_value'] ?? 'N/A';
    final clsValue = audit['cls_value'] ?? 'N/A';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorHelpers.getScoreColor(performanceScore).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: ColorHelpers.getScoreColor(performanceScore), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Performance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${performanceScore.toInt()}/100',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: ColorHelpers.getScoreColor(performanceScore),
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  trend > 0 ? Icons.trending_up : (trend < 0 ? Icons.trending_down : Icons.trending_flat),
                  size: 16,
                  color: trend > 0 ? Colors.green : (trend < 0 ? Colors.red : Colors.grey),
                ),
                const SizedBox(width: 4),
                Text(
                  '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: trend > 0 ? Colors.green : (trend < 0 ? Colors.red : Colors.grey),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: Colors.grey[800]),
          const SizedBox(height: 12),
          Text(
            'Core Web Vitals',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildVitalRow('LCP', lcpValue),
          _buildVitalRow('FCP', fcpValue),
          _buildVitalRow('CLS', clsValue),
        ],
      ),
    );
  }

  Widget _buildVitalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSEOIssuesCard(int total, int high, int medium, int low, double? trend) {
    final color = total == 0 ? Colors.green : (total < 5 ? Colors.orange : Colors.red);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: color, size: 20),
              const SizedBox(width: 8),
              const Text(
                'SEO Issues',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$total',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  trend < 0 ? Icons.trending_down : (trend > 0 ? Icons.trending_up : Icons.trending_flat),
                  size: 16,
                  color: trend < 0 ? Colors.green : (trend > 0 ? Colors.red : Colors.grey),
                ),
                const SizedBox(width: 4),
                Text(
                  '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: trend < 0 ? Colors.green : (trend > 0 ? Colors.red : Colors.grey),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: Colors.grey[800]),
          const SizedBox(height: 12),
          Text(
            'By Severity',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildSeverityRow('High', high, Colors.red),
          _buildSeverityRow('Medium', medium, Colors.orange),
          _buildSeverityRow('Low', low, Colors.yellow[700]!),
        ],
      ),
    );
  }

  Widget _buildSeverityRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: count > 0 ? color : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedBotAccessCard(int allowed, int blocked, int checked) {
    final color = allowed == checked ? Colors.green : Colors.orange;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: color, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Bot Access',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$allowed/$checked',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'allowed',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[800]),
          const SizedBox(height: 12),
          _buildBotRow('Allowed', allowed, Colors.green),
          _buildBotRow('Blocked', blocked, Colors.red),
        ],
      ),
    );
  }

  Widget _buildBotRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                label == 'Allowed' ? Icons.check_circle : Icons.block,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: count > 0 ? color : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

