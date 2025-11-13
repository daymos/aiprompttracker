import 'package:flutter/material.dart';

class ExpandableAuditHistoryItem extends StatefulWidget {
  final Map<String, dynamic> audit;
  final Color Function(double) getScoreColor;

  const ExpandableAuditHistoryItem({
    super.key,
    required this.audit,
    required this.getScoreColor,
  });

  @override
  State<ExpandableAuditHistoryItem> createState() => _ExpandableAuditHistoryItemState();
}

class _ExpandableAuditHistoryItemState extends State<ExpandableAuditHistoryItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(widget.audit['created_at']);
    final performanceScore = widget.audit['performance_score'] ?? 0;
    final seoIssues = widget.audit['seo_issues_count'] ?? 0;
    final seoIssuesHigh = widget.audit['seo_issues_high'] ?? 0;
    final seoIssuesMedium = widget.audit['seo_issues_medium'] ?? 0;
    final seoIssuesLow = widget.audit['seo_issues_low'] ?? 0;
    final lcpValue = widget.audit['lcp_value'] ?? 'N/A';
    final fcpValue = widget.audit['fcp_value'] ?? 'N/A';
    final clsValue = widget.audit['cls_value'] ?? 'N/A';
    final tbtValue = widget.audit['tbt_value'] ?? 'N/A';
    final ttiValue = widget.audit['tti_value'] ?? 'N/A';
    final fullAuditData = widget.audit['full_audit_data'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: _isExpanded ? Border.all(color: Colors.grey[700]!, width: 1) : null,
      ),
      child: Column(
        children: [
          // Main row (always visible)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Date
                  SizedBox(
                    width: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${date.month}/${date.day}/${date.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Performance Score
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.getScoreColor(performanceScore).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${performanceScore.toInt()}/100',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // SEO Issues
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (seoIssues == 0 ? Colors.green : Colors.orange).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$seoIssues issue${seoIssues == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Core Web Vitals chips
                  _buildVitalChip('LCP', lcpValue),
                  const SizedBox(width: 4),
                  _buildVitalChip('FCP', fcpValue),
                  const SizedBox(width: 4),
                  _buildVitalChip('CLS', clsValue),
                  
                  const Spacer(),
                  
                  // Expand/Collapse icon
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded details
          if (_isExpanded) ...[
            Divider(color: Colors.grey[800], height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Performance Metrics Section
                  Text(
                    'Performance Metrics',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('LCP', lcpValue)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricCard('FCP', fcpValue)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricCard('CLS', clsValue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('TBT', tbtValue)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricCard('TTI', ttiValue)),
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox()), // Empty space
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // SEO Issues Section
                  if (seoIssues > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SEO Issues Breakdown',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[300],
                          ),
                        ),
                        Row(
                          children: [
                            _buildSeverityBadge('High', seoIssuesHigh, Colors.red),
                            const SizedBox(width: 8),
                            _buildSeverityBadge('Med', seoIssuesMedium, Colors.orange),
                            const SizedBox(width: 8),
                            _buildSeverityBadge('Low', seoIssuesLow, Colors.yellow[700]!),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (fullAuditData != null && fullAuditData['raw_data'] != null) ...[
                      _buildIssuesList(fullAuditData),
                    ] else ...[
                      Text(
                        'No detailed issue data available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'No SEO issues found! 🎉',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesList(Map<String, dynamic> fullAuditData) {
    final rawData = fullAuditData['raw_data'] as Map?;
    if (rawData == null) {
      return const SizedBox.shrink();
    }

    final seoData = rawData['seo'] as Map?;
    if (seoData == null) {
      return const SizedBox.shrink();
    }

    final issues = seoData['issues'] as List? ?? [];
    if (issues.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to first 5 issues for brevity
    final displayIssues = issues.take(5).toList();

    return Column(
      children: [
        ...displayIssues.map((issue) => _buildIssueItem(issue as Map<String, dynamic>)).toList(),
        if (issues.length > 5) ...[
          const SizedBox(height: 8),
          Text(
            '+ ${issues.length - 5} more issues',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIssueItem(Map<String, dynamic> issue) {
    final severity = issue['severity'] ?? 'low';
    final type = issue['type'] ?? 'Unknown';
    final description = issue['description'] ?? 'No description';
    final pageUrl = issue['page_url'] as String?;
    
    Color severityColor;
    if (severity == 'high') {
      severityColor = Colors.red;
    } else if (severity == 'medium') {
      severityColor = Colors.orange;
    } else {
      severityColor = Colors.yellow[700]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: severityColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: severityColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (pageUrl != null && pageUrl.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 10,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pageUrl,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

