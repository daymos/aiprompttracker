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
                  // Search and filter controls
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      children: [
                        // Search bar
                        SizedBox(
                          width: 300,
                          height: 36,
                          child: TextField(
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search keywords...',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 18),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _keywordSearchQuery = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Filter chips
                        Wrap(
                          spacing: 6,
                          children: [
                            ChoiceChip(
                              label: const Text('All', style: TextStyle(fontSize: 12)),
                              selected: _keywordFilter == 'all',
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              labelPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onSelected: (selected) {
                                if (selected) setState(() => _keywordFilter = 'all');
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Tracking', style: TextStyle(fontSize: 12)),
                              selected: _keywordFilter == 'tracking',
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              labelPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onSelected: (selected) {
                                if (selected) setState(() => _keywordFilter = 'tracking');
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Suggestions', style: TextStyle(fontSize: 12)),
                              selected: _keywordFilter == 'suggestions',
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              labelPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onSelected: (selected) {
                                if (selected) setState(() => _keywordFilter = 'suggestions');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Sort dropdown
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _keywordSortBy,
                            underline: const SizedBox(),
                            style: const TextStyle(fontSize: 13),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'position', child: Text('Position')),
                              DropdownMenuItem(value: 'name', child: Text('Name')),
                              DropdownMenuItem(value: 'volume', child: Text('Volume')),
                              DropdownMenuItem(value: 'status', child: Text('Status')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _keywordSortBy = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Sort direction
                        IconButton(
                          icon: Icon(
                            _keywordSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 18,
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: _keywordSortAscending ? 'Ascending' : 'Descending',
                          onPressed: () {
                            setState(() => _keywordSortAscending = !_keywordSortAscending);
                          },
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
                            ],
                            data: filteredKeywords.map((keyword) {
                              return {
                                'id': keyword.id,
                                'keyword': keyword.keyword,
                                'currentPosition': keyword.currentPosition,
                                'searchVolume': keyword.searchVolume,
                                'seoDifficulty': keyword.seoDifficulty,
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

