import 'package:flutter/material.dart';
import 'package:keywordschat/utils/formatting_utils.dart';
import 'package:keywordschat/widgets/competition_chip.dart';
import 'package:keywordschat/widgets/data_panel.dart'; // Import DataColumnConfig

/// Central configuration for all table column layouts
class TableColumnConfigs {
  /// Main dispatcher that selects the right column config based on title
  static List<DataColumnConfig> buildDataPanelColumns(String title) {
    // Detect data type from title or data structure
    if (title.toLowerCase().contains('ranking')) {
      return buildRankingColumns();
    } else if (title.toLowerCase().contains('comprehensive') || title.toLowerCase().contains('complete audit')) {
      return buildComprehensiveAuditColumns();
    } else if (title.toLowerCase().contains('technical') || title.toLowerCase().contains('seo issue')) {
      return buildTechnicalSEOColumns();
    } else if (title.toLowerCase().contains('ai bot') || title.toLowerCase().contains('bot access')) {
      return buildAIBotAccessColumns();
    } else if (title.toLowerCase().contains('performance') || title.toLowerCase().contains('web vitals')) {
      return buildPerformanceColumns();
    }
    // Default to keyword columns
    return buildKeywordColumns();
  }
  
  /// Build column configs for tabs based on tab names and data
  static Map<String, List<DataColumnConfig>> buildTabColumns(Map<String, List<Map<String, dynamic>>> tabs) {
    final tabColumns = <String, List<DataColumnConfig>>{};
    
    for (final tabName in tabs.keys) {
      final tabNameLower = tabName.toLowerCase();
      
      // Determine columns based on tab name
      if (tabNameLower.contains('keyword')) {
        tabColumns[tabName] = buildKeywordColumns();
      } else if (tabNameLower.contains('ranking')) {
        tabColumns[tabName] = buildRankingColumns();
      } else if (tabNameLower.contains('seo issue') || tabNameLower.contains('tech seo')) {
        tabColumns[tabName] = buildTechnicalSEOColumns();
      } else if (tabNameLower.contains('performance')) {
        tabColumns[tabName] = buildPerformanceColumns();
      } else if (tabNameLower.contains('ai bot') || tabNameLower.contains('bot')) {
        tabColumns[tabName] = buildAIBotAccessColumns();
      } else if (tabNameLower.contains('page summar')) {
        tabColumns[tabName] = buildPageSummaryColumns();
      } else if (tabNameLower.contains('audit')) {
        tabColumns[tabName] = buildComprehensiveAuditColumns();
      } else {
        // Try to infer from data structure if we have data
        final tabData = tabs[tabName];
        if (tabData != null && tabData.isNotEmpty) {
          final firstRow = tabData.first;
          
          // Check for keyword data structure
          if (firstRow.containsKey('keyword') && firstRow.containsKey('search_volume')) {
            tabColumns[tabName] = buildKeywordColumns();
          } 
          // Check for ranking data structure
          else if (firstRow.containsKey('url') && firstRow.containsKey('position')) {
            tabColumns[tabName] = buildRankingColumns();
          }
          // Check for SEO issue structure
          else if (firstRow.containsKey('issue') || firstRow.containsKey('severity')) {
            tabColumns[tabName] = buildTechnicalSEOColumns();
          }
          // Default fallback
          else {
            tabColumns[tabName] = buildKeywordColumns();
          }
        } else {
          // Empty tab, use keyword columns as default
          tabColumns[tabName] = buildKeywordColumns();
        }
      }
    }
    
    return tabColumns;
  }

  static List<DataColumnConfig> buildKeywordColumns() {
    return [
      DataColumnConfig(
        id: 'keyword',
        label: 'Keyword',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            row['keyword']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'search_volume',
        label: 'Volume',
        numeric: true,
        sortable: true,
        cellBuilder: (row) => Text(
          FormattingUtils.formatNumber(row['search_volume']),
          style: const TextStyle(fontSize: 11),
        ),
        csvFormatter: (value) => value?.toString() ?? '0',
      ),
      DataColumnConfig(
        id: 'ad_competition',
        label: 'Ad Comp',
        sortable: true,
        cellBuilder: (row) => CompetitionChip(competition: row['ad_competition']?.toString() ?? ''),
        csvFormatter: (value) => value?.toString() ?? '',
      ),
      DataColumnConfig(
        id: 'seo_difficulty',
        label: 'SEO Diff',
        numeric: true,
        sortable: true,
        cellBuilder: (row) {
          final difficulty = row['seo_difficulty'];
          if (difficulty == null) {
            return const Text('-', style: TextStyle(fontSize: 11, color: Colors.grey));
          }
          
          // Color based on difficulty
          Color difficultyColor;
          if (difficulty < 30) {
            difficultyColor = Colors.green;
          } else if (difficulty < 60) {
            difficultyColor = Colors.orange;
          } else {
            difficultyColor = Colors.red;
          }
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: difficultyColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              difficulty.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: difficultyColor,
              ),
            ),
          );
        },
        csvFormatter: (value) => value?.toString() ?? '',
      ),
      DataColumnConfig(
        id: 'cpc',
        label: 'CPC',
        numeric: true,
        sortable: true,
        cellBuilder: (row) => Text(
          '\$${(row['cpc'] ?? 0).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 11),
        ),
        csvFormatter: (value) => (value ?? 0).toStringAsFixed(2),
      ),
      DataColumnConfig(
        id: 'intent',
        label: 'Intent',
        sortable: true,
        cellBuilder: (row) => Text(
          row['intent']?.toString() ?? 'unknown',
          style: const TextStyle(fontSize: 11),
        ),
        csvFormatter: (value) => value?.toString() ?? 'unknown',
      ),
      DataColumnConfig(
        id: 'trend',
        label: 'Trend',
        numeric: true,
        sortable: true,
        cellBuilder: (row) => Text(
          '${(row['trend'] ?? 0).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 11),
        ),
        csvFormatter: (value) => (value ?? 0).toStringAsFixed(1),
      ),
    ];
  }

  static List<DataColumnConfig> buildRankingColumns() {
    return [
      DataColumnConfig(
        id: 'keyword',
        label: 'Keyword',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            row['keyword']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'position',
        label: 'Position',
        numeric: true,
        sortable: true,
        cellBuilder: (row) {
          final position = row['position'];
          if (position == null) {
            return const Text(
              'Not ranking',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            );
          }
          // Color code based on position
          Color positionColor;
          if (position <= 3) {
            positionColor = Colors.green;
          } else if (position <= 10) {
            positionColor = Colors.blue;
          } else if (position <= 20) {
            positionColor = Colors.orange;
          } else {
            positionColor = Colors.grey;
          }
          return Text(
            '#$position',
            style: TextStyle(
              fontSize: 11,
              color: positionColor,
              fontWeight: FontWeight.bold,
            ),
          );
        },
        csvFormatter: (value) => value?.toString() ?? 'Not ranking',
      ),
      DataColumnConfig(
        id: 'url',
        label: 'Ranking URL',
        sortable: true,
        cellBuilder: (row) {
          final url = row['url']?.toString() ?? '';
          if (url.isEmpty) return const Text('', style: TextStyle(fontSize: 11));
          
          // Extract path from URL for display
          try {
            final uri = Uri.parse(url);
            final displayPath = uri.path.length > 30 
                ? '${uri.path.substring(0, 27)}...'
                : uri.path;
            return Text(
              displayPath.isEmpty ? '/' : displayPath,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            );
          } catch (e) {
            return Text(
              url.length > 30 ? '${url.substring(0, 27)}...' : url,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            );
          }
        },
        csvFormatter: (value) => value?.toString() ?? '',
      ),
      DataColumnConfig(
        id: 'title',
        label: 'Page Title',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            row['title']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    ];
  }

  static List<DataColumnConfig> buildTechnicalSEOColumns() {
    return [
      DataColumnConfig(
        id: 'severity',
        label: 'Severity',
        sortable: true,
        cellBuilder: (row) {
          final severity = row['severity']?.toString().toLowerCase() ?? 'low';
          Color severityColor;
          IconData severityIcon;
          
          if (severity == 'high') {
            severityColor = Colors.red;
            severityIcon = Icons.error;
          } else if (severity == 'medium') {
            severityColor = Colors.orange;
            severityIcon = Icons.warning;
          } else {
            severityColor = Colors.blue;
            severityIcon = Icons.info;
          }
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(severityIcon, size: 14, color: severityColor),
              const SizedBox(width: 4),
              Text(
                severity.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: severityColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
        csvFormatter: (value) => value?.toString() ?? 'low',
      ),
      DataColumnConfig(
        id: 'type',
        label: 'Issue Type',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            row['type']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'page',
        label: 'Page',
        sortable: true,
        cellBuilder: (row) {
          final page = row['page']?.toString() ?? '';
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              page.isEmpty ? '/' : page,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          );
        },
      ),
      DataColumnConfig(
        id: 'description',
        label: 'Description',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            row['description']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'recommendation',
        label: 'How to Fix',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            row['recommendation']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontSize: 11, color: Colors.green),
          ),
        ),
      ),
    ];
  }

  static List<DataColumnConfig> buildAIBotAccessColumns() {
    return [
      DataColumnConfig(
        id: 'bot_name',
        label: 'AI Bot / Crawler',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            row['bot_name']?.toString() ?? '',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'status',
        label: 'Access Status',
        sortable: true,
        cellBuilder: (row) {
          final status = row['status']?.toString().toLowerCase() ?? 'unknown';
          Color statusColor;
          IconData statusIcon;
          String displayText;
          
          if (status == 'allowed' || status == 'can crawl') {
            statusColor = Colors.green;
            statusIcon = Icons.check_circle;
            displayText = 'Allowed';
          } else if (status == 'blocked' || status == 'cannot crawl') {
            statusColor = Colors.red;
            statusIcon = Icons.block;
            displayText = 'Blocked';
          } else {
            statusColor = Colors.grey;
            statusIcon = Icons.help_outline;
            displayText = 'Unknown';
          }
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
        csvFormatter: (value) => value?.toString() ?? 'unknown',
      ),
      DataColumnConfig(
        id: 'user_agent',
        label: 'User Agent',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            row['user_agent']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'purpose',
        label: 'Purpose',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            row['purpose']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    ];
  }

  static List<DataColumnConfig> buildPageSummaryColumns() {
    return [
      DataColumnConfig(
        id: 'url',
        label: 'Page URL',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Text(
            row['url']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'performance_score',
        label: 'Performance',
        sortable: true,
        cellBuilder: (row) {
          final score = (row['performance_score'] as num?)?.toDouble() ?? 0.0;
          Color scoreColor;
          if (score >= 90) {
            scoreColor = Colors.green;
          } else if (score >= 50) {
            scoreColor = Colors.orange;
          } else {
            scoreColor = Colors.red;
          }
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scoreColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${score.toStringAsFixed(0)}/100',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ],
          );
        },
        csvFormatter: (value) => value?.toString() ?? '0',
      ),
      DataColumnConfig(
        id: 'seo_issues_count',
        label: 'Total Issues',
        sortable: true,
        cellBuilder: (row) {
          final count = row['seo_issues_count'] as int? ?? 0;
          return Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: count > 0 ? Colors.orange : Colors.green,
            ),
          );
        },
        csvFormatter: (value) => value?.toString() ?? '0',
      ),
      DataColumnConfig(
        id: 'seo_issues_high',
        label: 'High',
        sortable: true,
        cellBuilder: (row) {
          final count = row['seo_issues_high'] as int? ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.red.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: count > 0 ? Colors.red : Colors.grey,
              ),
            ),
          );
        },
        csvFormatter: (value) => value?.toString() ?? '0',
      ),
      DataColumnConfig(
        id: 'seo_issues_medium',
        label: 'Medium',
        sortable: true,
        cellBuilder: (row) {
          final count = row['seo_issues_medium'] as int? ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.orange.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: count > 0 ? Colors.orange : Colors.grey,
              ),
            ),
          );
        },
        csvFormatter: (value) => value?.toString() ?? '0',
      ),
      DataColumnConfig(
        id: 'seo_issues_low',
        label: 'Low',
        sortable: true,
        cellBuilder: (row) {
          final count = row['seo_issues_low'] as int? ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.yellow.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: count > 0 ? Colors.yellow[700] : Colors.grey,
              ),
            ),
          );
        },
        csvFormatter: (value) => value?.toString() ?? '0',
      ),
    ];
  }

  static List<DataColumnConfig> buildPerformanceColumns() {
    return [
      DataColumnConfig(
        id: 'metric_name',
        label: 'Metric',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            row['metric_name']?.toString() ?? '',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'value',
        label: 'Value',
        sortable: true,
        cellBuilder: (row) => Text(
          row['value']?.toString() ?? '',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      DataColumnConfig(
        id: 'score',
        label: 'Score',
        numeric: true,
        sortable: true,
        cellBuilder: (row) {
          final score = row['score'];
          if (score == null) return const Text('N/A', style: TextStyle(fontSize: 11));
          
          final scoreValue = score is num ? score : (double.tryParse(score.toString()) ?? 0);
          Color scoreColor;
          
          if (scoreValue >= 90) {
            scoreColor = Colors.green;
          } else if (scoreValue >= 50) {
            scoreColor = Colors.orange;
          } else {
            scoreColor = Colors.red;
          }
          
          return Text(
            scoreValue.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 11,
              color: scoreColor,
              fontWeight: FontWeight.bold,
            ),
          );
        },
        csvFormatter: (value) => value?.toString() ?? 'N/A',
      ),
      DataColumnConfig(
        id: 'rating',
        label: 'Rating',
        sortable: true,
        cellBuilder: (row) {
          final rating = row['rating']?.toString().toUpperCase() ?? 'N/A';
          Color ratingColor;
          
          if (rating == 'GOOD') {
            ratingColor = Colors.green;
          } else if (rating == 'NEEDS IMPROVEMENT') {
            ratingColor = Colors.orange;
          } else if (rating == 'POOR') {
            ratingColor = Colors.red;
          } else {
            ratingColor = Colors.grey;
          }
          
          return Text(
            rating,
            style: TextStyle(
              fontSize: 11,
              color: ratingColor,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
      DataColumnConfig(
        id: 'description',
        label: 'Description',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            row['description']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    ];
  }

  static List<DataColumnConfig> buildComprehensiveAuditColumns() {
    return [
      DataColumnConfig(
        id: 'category',
        label: 'Category',
        sortable: true,
        cellBuilder: (row) {
          final category = row['category']?.toString() ?? '';
          Color categoryColor;
          IconData categoryIcon;
          
          if (category == 'Technical SEO') {
            categoryColor = Colors.blue;
            categoryIcon = Icons.verified;
          } else if (category == 'Performance') {
            categoryColor = Colors.orange;
            categoryIcon = Icons.speed;
          } else if (category == 'AI Bot Access') {
            categoryColor = Colors.purple;
            categoryIcon = Icons.smart_toy;
          } else {
            categoryColor = Colors.grey;
            categoryIcon = Icons.info;
          }
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(categoryIcon, size: 14, color: categoryColor),
              const SizedBox(width: 4),
              Text(
                category,
                style: TextStyle(
                  fontSize: 11,
                  color: categoryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
      DataColumnConfig(
        id: 'item_name',
        label: 'Item',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            row['item_name']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'status',
        label: 'Status',
        sortable: true,
        cellBuilder: (row) {
          final status = row['status']?.toString() ?? '';
          Color statusColor;
          IconData statusIcon;
          
          final statusLower = status.toLowerCase();
          if (statusLower == 'good' || statusLower == 'allowed') {
            statusColor = Colors.green;
            statusIcon = Icons.check_circle;
          } else if (statusLower.contains('medium') || statusLower.contains('needs improvement')) {
            statusColor = Colors.orange;
            statusIcon = Icons.warning;
          } else if (statusLower.contains('high') || statusLower == 'poor' || statusLower == 'blocked') {
            statusColor = Colors.red;
            statusIcon = Icons.error;
          } else {
            statusColor = Colors.blue;
            statusIcon = Icons.info;
          }
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
      DataColumnConfig(
        id: 'value',
        label: 'Value',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            row['value']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'location',
        label: 'Location',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            row['location']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'recommendation',
        label: 'Details / Recommendation',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            row['recommendation']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    ];
  }
}

