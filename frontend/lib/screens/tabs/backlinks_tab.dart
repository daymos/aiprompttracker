import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../utils/backlink_filters.dart';
import '../../widgets/sortable_data_table.dart';

/// Tab for displaying and managing project backlinks
class BacklinksTab extends StatefulWidget {
  final Project project;

  const BacklinksTab({
    super.key,
    required this.project,
  });

  @override
  State<BacklinksTab> createState() => _BacklinksTabState();
}

class _BacklinksTabState extends State<BacklinksTab> {
  String _backlinkSearchQuery = '';

  List<Map<String, dynamic>> _filterBacklinks(List<Map<String, dynamic>> backlinks) {
    if (_backlinkSearchQuery.isEmpty) return backlinks;
    
    return backlinks.where((backlink) {
      final sourceUrl = (backlink['url_from'] as String?)?.toLowerCase() ?? '';
      final anchor = (backlink['anchor'] as String?)?.toLowerCase() ?? '';
      final query = _backlinkSearchQuery.toLowerCase();
      
      return sourceUrl.contains(query) || anchor.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final authProvider = context.watch<AuthProvider>();

    // Load backlinks data if not loaded yet
    if (projectProvider.backlinksData == null && !projectProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        projectProvider.loadBacklinksData(authProvider.apiService, widget.project.id);
      });
    }

    if (projectProvider.isLoading && projectProvider.backlinksData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (projectProvider.backlinksData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => projectProvider.loadBacklinksData(authProvider.apiService, widget.project.id),
              icon: const Icon(Icons.refresh),
              tooltip: 'Load backlinks data',
            ),
            const SizedBox(height: 16),
            const Text('Click to load backlinks data'),
          ],
        ),
      );
    }

    final data = projectProvider.backlinksData;
    final allBacklinks = (data?['backlinks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final filteredBacklinks = _filterBacklinks(allBacklinks);

    if (allBacklinks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No Backlinks Analyzed Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click the button below to analyze backlinks for this project',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await projectProvider.refreshBacklinks(authProvider.apiService, widget.project.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backlinks analyzed!')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Analyze Backlinks'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
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
                  'Monitor the quality and authority of websites linking to your content',
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
                    hintText: 'Search backlinks...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                    suffixIcon: _backlinkSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() => _backlinkSearchQuery = '');
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
                    setState(() => _backlinkSearchQuery = value);
                  },
                ),
              ),
            ],
          ),
        ),
        // Backlinks table
        Expanded(
          child: SortableDataTable(
              columns: [
                TableColumn(
                  key: 'url_from',
                  label: 'Source URL',
                  sortable: true,
                  builder: (value, row) {
                    final sourceUrl = value as String?;
                    return Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              sourceUrl ?? 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[300],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                TableColumn(
                  key: 'anchor',
                  label: 'Anchor',
                  sortable: true,
                  tooltip: 'Anchor text used in the link',
                  builder: (value, row) {
                    final anchor = value as String?;
                    if (anchor == null || anchor.isEmpty) {
                      return Text(
                        '--',
                        style: TextStyle(color: Colors.grey[500]),
                      );
                    }
                    return Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        anchor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
                TableColumn(
                  key: 'inlink_rank',
                  label: 'Rank',
                  numeric: true,
                  sortable: true,
                  tooltip: 'Link quality/authority score',
                  builder: (value, row) {
                    final rank = value as num?;
                    if (rank == null) return const Text('--');
                    final rankInt = rank.round();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRankColor(rankInt).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rankInt.toString(),
                        style: TextStyle(
                          color: _getRankColor(rankInt),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
                TableColumn(
                  key: 'nofollow',
                  label: 'Status',
                  sortable: true,
                  tooltip: 'Link follow status',
                  builder: (value, row) {
                    final isNofollow = value == true;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isNofollow 
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isNofollow ? Colors.orange : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isNofollow ? 'Nofollow' : 'Follow',
                        style: TextStyle(
                          color: isNofollow ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ],
              data: filteredBacklinks.map((backlink) {
                return {
                  'id': backlink['url_from'] ?? '',
                  'url_from': backlink['url_from'],
                  'anchor': backlink['anchor'],
                  'inlink_rank': backlink['inlink_rank'],
                  'nofollow': backlink['nofollow'] ?? false,
                };
              }).toList(),
              emptyMessage: 'No backlinks found',
              onRowTap: (row) async {
                final sourceUrl = row['url_from'] as String?;
                if (sourceUrl != null) {
                  final uri = Uri.parse(sourceUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    if (rank >= 80) return Colors.green;
    if (rank >= 60) return Colors.lightGreen;
    if (rank >= 40) return Colors.orange;
    if (rank >= 20) return Colors.deepOrange;
    return Colors.red;
  }
}

