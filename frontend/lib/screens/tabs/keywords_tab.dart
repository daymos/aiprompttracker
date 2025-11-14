import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../widgets/cli_spinner.dart';
import '../../widgets/sortable_data_table.dart';
import '../../widgets/chart_painters.dart';
import '../../utils/keyword_filters.dart';
import '../../utils/color_helpers.dart';

/// Tab for displaying and managing tracked keywords
class KeywordsTab extends StatefulWidget {
  final ProjectProvider projectProvider;
  final List<TrackedKeyword> keywords;
  final VoidCallback onAddKeyword;

  const KeywordsTab({
    super.key,
    required this.projectProvider,
    required this.keywords,
    required this.onAddKeyword,
  });

  @override
  State<KeywordsTab> createState() => _KeywordsTabState();
}

class _KeywordsTabState extends State<KeywordsTab> {
  String _keywordSearchQuery = '';
  String _keywordFilter = 'all';
  String _keywordSortBy = 'position';
  bool _keywordSortAscending = true;

  List<TrackedKeyword> _filterAndSortKeywords(List<TrackedKeyword> keywords) {
    return KeywordFilters.filterAndSort(
      keywords,
      searchQuery: _keywordSearchQuery,
      filter: _keywordFilter,
      sortBy: _keywordSortBy,
      sortAscending: _keywordSortAscending,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Apply filtering and sorting
    final filteredKeywords = _filterAndSortKeywords(widget.keywords);
    
    return widget.projectProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : widget.keywords.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CliSpinner(
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Auto-detecting keywords',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ThinkingIndicator(
                          text: '',
                          fontSize: 20,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analyzing your website to suggest relevant keywords.\nThis may take 1-5 minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You can add keywords manually from the chat while you wait',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Header with description and search
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Description text on the left
                        Expanded(
                          child: Text(
                            'Track keyword rankings and monitor your SEO performance',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Search bar on the right
                        SizedBox(
                          width: 300,
                          child: TextField(
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search keywords...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 18,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                              ),
                              suffixIcon: _keywordSearchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() => _keywordSearchQuery = '');
                                      },
                                    )
                                  : null,
                              isDense: true,
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey[900] 
                                  : Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[800]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[800]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _keywordSearchQuery = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Keywords table
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: SortableDataTable(
                            columns: [
                              TableColumn(
                                key: 'keyword',
                                label: 'Keyword',
                                sortable: true,
                                builder: (value, row) {
                                  return Container(
                                    constraints: const BoxConstraints(maxWidth: 250),
                                    child: Text(
                                      value.toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              TableColumn(
                                key: 'status',
                                label: 'Status',
                                sortable: true,
                                tooltip: 'Tracking status',
                                builder: (value, row) {
                                  final keyword = filteredKeywords.firstWhere((k) => k.id == row['id']);
                                  final isTracking = keyword.isActive;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isTracking 
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isTracking ? Colors.green : Colors.orange,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      isTracking ? 'Tracking' : 'Suggested',
                                      style: TextStyle(
                                        color: isTracking ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              TableColumn(
                                key: 'currentPosition',
                                label: 'Rank',
                                numeric: true,
                                sortable: true,
                                tooltip: 'Current ranking position',
                                builder: (value, row) {
                                  final position = value as int?;
                                  if (position == null) {
                                    return Text(
                                      '--',
                                      style: TextStyle(color: Colors.grey[500]),
                                    );
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: ColorHelpers.getPositionColor(position).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#$position',
                                      style: TextStyle(
                                        color: ColorHelpers.getPositionColor(position),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              TableColumn(
                                key: 'searchVolume',
                                label: 'Volume',
                                numeric: true,
                                sortable: true,
                                tooltip: 'Monthly search volume',
                              ),
                              TableColumn(
                                key: 'seoDifficulty',
                                label: 'KD',
                                numeric: true,
                                sortable: true,
                                tooltip: 'Keyword Difficulty (0-100)',
                                builder: (value, row) {
                                  final kd = value as int?;
                                  if (kd == null) return const Text('--');
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: ColorHelpers.getSeoDifficultyColor(kd).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      kd.toString(),
                                      style: TextStyle(
                                        color: ColorHelpers.getSeoDifficultyColor(kd),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              TableColumn(
                                key: 'trend',
                                label: 'Trend',
                                sortable: false,
                                builder: (value, row) {
                                  final keyword = filteredKeywords.firstWhere((k) => k.id == row['id']);
                                  if (keyword.rankingHistory.length >= 2) {
                                    final positions = keyword.rankingHistory
                                        .map((point) => point.position)
                                        .where((p) => p != null)
                                        .map((p) => p!.toDouble())
                                        .toList();

                                    if (positions.length >= 2) {
                                      final firstPos = positions.first;
                                      final lastPos = positions.last;
                                      final change = firstPos - lastPos;
                                      final isImproving = change > 0;

                                      return SizedBox(
                                        width: 50,
                                        height: 24,
                                        child: CustomPaint(
                                          painter: SparklinePainter(
                                            positions,
                                            isImproving ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                  return SizedBox(
                                    width: 50,
                                    height: 24,
                                    child: CustomPaint(
                                      painter: NoDataSparklinePainter(
                                        Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              TableColumn(
                                key: 'targetPage',
                                label: 'Target Page',
                                sortable: true,
                                tooltip: 'Page/post targeting this keyword',
                                builder: (value, row) {
                                  final keyword = filteredKeywords.firstWhere((k) => k.id == row['id']);
                                  final targetPage = keyword.targetPage;
                                  
                                  if (targetPage == null || targetPage.isEmpty) {
                                    return Text(
                                      'Not set',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  }
                                  
                                  // Extract path from URL for display
                                  String displayText = targetPage;
                                  try {
                                    final uri = Uri.parse(targetPage);
                                    displayText = uri.path.isEmpty ? uri.host : uri.path;
                                    if (displayText.startsWith('/')) {
                                      displayText = displayText.substring(1);
                                    }
                                  } catch (e) {
                                    // If parsing fails, use original text
                                  }
                                  
                                  return Container(
                                    constraints: const BoxConstraints(maxWidth: 200),
                                    child: Tooltip(
                                      message: targetPage,
                                      child: Text(
                                        displayText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[300],
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            data: filteredKeywords.map((keyword) {
                              return {
                                'id': keyword.id,
                                'keyword': keyword.keyword,
                                'status': keyword.isActive ? 'Tracking' : 'Suggested',
                                'currentPosition': keyword.currentPosition,
                                'searchVolume': keyword.searchVolume,
                                'seoDifficulty': keyword.seoDifficulty,
                                'targetPage': keyword.targetPage,
                              };
                            }).toList(),
                            emptyMessage: 'No keywords found',
                          ),
                        ),
                        // Add keyword button at bottom
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton.icon(
                            onPressed: widget.onAddKeyword,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Keyword'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
  }
}

