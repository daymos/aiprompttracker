import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../utils/backlink_filters.dart';

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
  String _backlinkFilter = 'all';
  String _backlinkSortBy = 'rank';
  bool _backlinkSortAscending = false;

  List<Map<String, dynamic>> _filterAndSortBacklinks(List<Map<String, dynamic>> backlinks) {
    return BacklinkFilters.filterAndSort(
      backlinks,
      searchQuery: _backlinkSearchQuery,
      filter: _backlinkFilter,
      sortBy: _backlinkSortBy,
      sortAscending: _backlinkSortAscending,
    );
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
    final filteredBacklinks = _filterAndSortBacklinks(allBacklinks);

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
        // Search, Filter, and Sort Controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Search field
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search backlinks...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 16),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _backlinkSearchQuery = value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Filter chips
              Wrap(
                spacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('All', style: TextStyle(fontSize: 12)),
                    selected: _backlinkFilter == 'all',
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    labelPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _backlinkFilter = 'all');
                      }
                    },
                  ),
                  const SizedBox(width: 2),
                  ChoiceChip(
                    label: const Text('Follow', style: TextStyle(fontSize: 12)),
                    selected: _backlinkFilter == 'follow',
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    labelPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _backlinkFilter = 'follow');
                      }
                    },
                  ),
                  const SizedBox(width: 2),
                  ChoiceChip(
                    label: const Text('Nofollow', style: TextStyle(fontSize: 12)),
                    selected: _backlinkFilter == 'nofollow',
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    labelPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _backlinkFilter = 'nofollow');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(width: 8),
              
              // Sort dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButton<String>(
                  value: _backlinkSortBy,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 13),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'rank', child: Text('Rank')),
                    DropdownMenuItem(value: 'anchor', child: Text('Anchor')),
                    DropdownMenuItem(value: 'source', child: Text('Source')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _backlinkSortBy = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              
              // Sort direction
              IconButton(
                icon: Icon(
                  _backlinkSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: _backlinkSortAscending ? 'Ascending' : 'Descending',
                onPressed: () {
                  setState(() => _backlinkSortAscending = !_backlinkSortAscending);
                },
              ),
            ],
          ),
        ),

        // Separator line
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),

        // List of backlinks
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0),
            itemCount: filteredBacklinks.length,
            itemBuilder: (context, index) {
              final backlink = filteredBacklinks[index];
              final sourceUrl = backlink['url_from'] as String?;
              final targetUrl = backlink['url_to'] as String?;
              final anchorText = backlink['anchor'] as String?;
              final inlinkRank = backlink['inlink_rank'] as num?;
              final isNofollow = backlink['nofollow'] == true;

              return InkWell(
                onTap: () async {
                  if (sourceUrl != null) {
                    final uri = Uri.parse(sourceUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      children: [
                        // Leading icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isNofollow 
                              ? Theme.of(context).colorScheme.surfaceVariant
                              : Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isNofollow ? Icons.link_off : Icons.link,
                            color: isNofollow
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.onPrimaryContainer,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Main content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sourceUrl ?? 'Unknown source',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                              if (anchorText != null && anchorText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Anchor: "$anchorText"',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (inlinkRank != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Quality: ${inlinkRank.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Trailing badge
                        if (isNofollow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NOFOLLOW',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

