import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'performance_dashboard.dart';

/// Column definition for the data table
class DataColumnConfig {
  final String id;
  final String label;
  final bool numeric;
  final bool sortable;
  final Widget Function(Map<String, dynamic> row)? cellBuilder;
  final String Function(dynamic value)? csvFormatter;
  
  const DataColumnConfig({
    required this.id,
    required this.label,
    this.numeric = false,
    this.sortable = true,
    this.cellBuilder,
    this.csvFormatter,
  });
}

class DataPanel extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<DataColumnConfig> columns;
  final String title;
  final VoidCallback onClose;
  final List<Map<String, dynamic>> projects;
  final Function(String projectId, List<Map<String, dynamic>>)? onAddToProject;
  final String? csvFilename;
  // For tabbed views (technical audits)
  final Map<String, List<Map<String, dynamic>>>? tabs;
  final Map<String, List<DataColumnConfig>>? tabColumns;
  final String? dataPanelUrl;

  const DataPanel({
    super.key,
    required this.data,
    required this.columns,
    required this.title,
    required this.onClose,
    this.projects = const [],
    this.onAddToProject,
    this.csvFilename,
    this.tabs,
    this.tabColumns,
    this.dataPanelUrl,
  });

  @override
  State<DataPanel> createState() => _DataPanelState();
}

class _DataPanelState extends State<DataPanel> with SingleTickerProviderStateMixin {
  String? _sortColumn;
  bool _sortAscending = false;
  final Set<int> _selectedRows = {};
  List<Map<String, dynamic>> _sortedData = [];
  double _panelWidth = 600; // Default width, can be resized
  TabController? _tabController;
  String? _currentTab;

  @override
  void initState() {
    super.initState();
    
    // Initialize tabs if present
    if (widget.tabs != null && widget.tabs!.isNotEmpty) {
      // Default to Performance tab if it exists, otherwise use first tab
      _currentTab = widget.tabs!.keys.contains('Performance') 
          ? 'Performance' 
          : widget.tabs!.keys.first;
      final initialIndex = widget.tabs!.keys.toList().indexOf(_currentTab!);
      _tabController = TabController(
        length: widget.tabs!.length, 
        vsync: this,
        initialIndex: initialIndex,
      );
      _sortedData = List.from(widget.tabs![_currentTab!]!);
    } else {
      _sortedData = List.from(widget.data);
    }
    
    // Sort by first numeric column by default
    final columns = _getCurrentColumns();
    final defaultSortColumn = columns.firstWhere(
      (col) => col.numeric && col.sortable,
      orElse: () => columns.first,
    );
    _sortColumn = defaultSortColumn.id;
    _onSort(_sortColumn!);
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
  
  List<DataColumnConfig> _getCurrentColumns() {
    if (widget.tabs != null && _currentTab != null && widget.tabColumns != null) {
      return widget.tabColumns![_currentTab!] ?? widget.columns;
    }
    return widget.columns;
  }
  
  List<Map<String, dynamic>> _getCurrentData() {
    if (widget.tabs != null && _currentTab != null) {
      return widget.tabs![_currentTab!] ?? [];
    }
    return widget.data;
  }
  
  void _onTabChanged(String tabName) {
    setState(() {
      _currentTab = tabName;
      _sortedData = List.from(widget.tabs![tabName]!);
      _selectedRows.clear();
      
      // Reset sort for new tab
      final columns = _getCurrentColumns();
      final defaultSortColumn = columns.firstWhere(
        (col) => col.numeric && col.sortable,
        orElse: () => columns.first,
      );
      _sortColumn = defaultSortColumn.id;
      _onSort(_sortColumn!);
    });
  }

  void _onSort(String columnId) {
    final columns = _getCurrentColumns();
    final column = columns.firstWhere((col) => col.id == columnId);
    if (!column.sortable) return;

    setState(() {
      if (_sortColumn == columnId) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = columnId;
        _sortAscending = false;
      }

      _sortedData.sort((a, b) {
        final aValue = a[columnId];
        final bValue = b[columnId];

        if (aValue == null && bValue == null) return 0;
        if (aValue == null) return 1;
        if (bValue == null) return -1;

        int comparison;
        if (aValue is num && bValue is num) {
          comparison = aValue.compareTo(bValue);
        } else {
          comparison = aValue.toString().compareTo(bValue.toString());
        }

        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedRows.length == _sortedData.length) {
        _selectedRows.clear();
      } else {
        _selectedRows.addAll(List.generate(_sortedData.length, (i) => i));
      }
    });
  }

  void _downloadCSV() {
    // Build CSV content
    final csvContent = StringBuffer();
    
    final columns = _getCurrentColumns();
    
    // Headers
    csvContent.writeln(columns.map((col) => col.label).join(','));
    
    // Data rows
    for (var row in _sortedData) {
      final values = columns.map((col) {
        final value = row[col.id];
        if (col.csvFormatter != null) {
          return col.csvFormatter!(value);
        }
        // Escape commas and quotes
        final stringValue = value?.toString() ?? '';
        if (stringValue.contains(',') || stringValue.contains('"')) {
          return '"${stringValue.replaceAll('"', '""')}"';
        }
        return stringValue;
      });
      csvContent.writeln(values.join(','));
    }
    
    // Create blob and download
    final bytes = utf8.encode(csvContent.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final filename = widget.csvFilename ?? 'data_${DateTime.now().millisecondsSinceEpoch}.csv';
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body?.children.add(anchor);
    
    anchor.click();
    
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV downloaded successfully')),
      );
    }
  }

  void _addSelectedToProject(String projectId) {
    if (_selectedRows.isEmpty || widget.onAddToProject == null) return;

    final selected = _selectedRows.map((i) => _sortedData[i]).toList();
    widget.onAddToProject?.call(projectId, selected);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Draggable divider for resizing
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _panelWidth = (_panelWidth - details.delta.dx).clamp(400.0, 1200.0);
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: Container(
              width: 4,
              color: Colors.grey[800],
              child: Center(
                child: Container(
                  width: 1,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
        // Panel content
        GestureDetector(
          // Prevent browser back gesture when scrolling horizontally
          onHorizontalDragUpdate: (_) {},
          child: Container(
            width: _panelWidth,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
            ),
            child: Column(
              children: [
                // Header
                Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[800]!, width: 1),
              ),
            ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Only show item count for tabs with tabular data (not Performance dashboard)
                            if (widget.tabs == null || _currentTab != 'Performance')
                              Text(
                                '${_sortedData.length} items',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: widget.onClose,
                        tooltip: 'Close panel',
                      ),
                    ],
                  ),
                ),

                // Tabs bar (if tabbed view)
                if (widget.tabs != null && widget.tabs!.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                    ),
                    child: Row(
                      children: widget.tabs!.keys.map((tabName) {
                        final isActive = tabName == _currentTab;
                        return GestureDetector(
                          onTap: () => _onTabChanged(tabName),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              tabName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive ? Colors.white : Colors.grey[400],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Actions bar - hide for Performance dashboard
                if (_currentTab != 'Performance')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedRows.length} selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: _downloadCSV,
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export CSV'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        // Only show "Add to Project" for keywords, not for audits
                        if (widget.tabs == null && widget.onAddToProject != null && widget.projects.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (projectId) => _addSelectedToProject(projectId),
                          enabled: _selectedRows.isNotEmpty,
                          itemBuilder: (context) => widget.projects.map((project) {
                            return PopupMenuItem<String>(
                              value: project['id'] as String,
                              child: Row(
                                children: [
                                  const Icon(Icons.folder, size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      project['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selectedRows.isEmpty ? Colors.grey[800] : Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 16,
                                  color: _selectedRows.isEmpty ? Colors.grey[600] : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Add to Project',
                                  style: TextStyle(
                                    color: _selectedRows.isEmpty ? Colors.grey[600] : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: _selectedRows.isEmpty ? Colors.grey[600] : Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Data content - either dashboard or table
                Expanded(
                  child: _currentTab == 'Performance' 
                    ? PerformanceDashboard(
                        metrics: _sortedData,
                        url: widget.dataPanelUrl ?? widget.title,
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // Prevent browser back gesture on horizontal scroll
                          return true;
                        },
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: DataTable(
                          horizontalMargin: 12,
                          columnSpacing: 16,
                          headingRowHeight: 40,
                          dataRowHeight: 36,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 11,
                          ),
                          headingRowColor: MaterialStateProperty.all(Colors.grey[850]),
                          dataRowColor: MaterialStateProperty.resolveWith((states) {
                            return states.contains(MaterialState.selected)
                                ? Colors.blue.withOpacity(0.1)
                                : null;
                          }),
                          showCheckboxColumn: true,
                          columns: _getCurrentColumns().map((col) {
                            return DataColumn(
                              label: Text(col.label),
                              onSort: col.sortable ? (_, __) => _onSort(col.id) : null,
                              numeric: col.numeric,
                            );
                          }).toList(),
                          rows: List.generate(_sortedData.length, (index) {
                            final item = _sortedData[index];
                            final isSelected = _selectedRows.contains(index);

                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedRows.add(index);
                                  } else {
                                    _selectedRows.remove(index);
                                  }
                                });
                              },
                              cells: _getCurrentColumns().map((col) {
                                if (col.cellBuilder != null) {
                                  return DataCell(col.cellBuilder!(item));
                                }
                                
                                // Default cell rendering
                                final value = item[col.id];
                                return DataCell(
                                  Text(
                                    value?.toString() ?? '',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              }).toList(),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

