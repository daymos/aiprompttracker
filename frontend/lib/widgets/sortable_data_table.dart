import 'package:flutter/material.dart';

/// A reusable sortable data table widget
class SortableDataTable extends StatefulWidget {
  final List<TableColumn> columns;
  final List<Map<String, dynamic>> data;
  final Function(Map<String, dynamic>)? onRowTap;
  final Set<String> selectedIds;
  final Function(String id, bool selected)? onSelectionChanged;
  final bool showCheckboxes;
  final String? emptyMessage;

  const SortableDataTable({
    super.key,
    required this.columns,
    required this.data,
    this.onRowTap,
    this.selectedIds = const {},
    this.onSelectionChanged,
    this.showCheckboxes = false,
    this.emptyMessage,
  });

  @override
  State<SortableDataTable> createState() => _SortableDataTableState();
}

class _SortableDataTableState extends State<SortableDataTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String? _hoveredRowId;
  List<Map<String, dynamic>> _sortedData = [];

  @override
  void initState() {
    super.initState();
    _sortedData = List.from(widget.data);
  }

  @override
  void didUpdateWidget(SortableDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _sortedData = List.from(widget.data);
      if (_sortColumnIndex != null) {
        _sortData(_sortColumnIndex!);
      }
    }
  }

  void _sortData(int columnIndex) {
    final column = widget.columns[columnIndex];
    if (!column.sortable) return;

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortedData.sort((a, b) {
        final aValue = a[column.key];
        final bValue = b[column.key];

        int compare = 0;
        if (aValue == null && bValue == null) {
          compare = 0;
        } else if (aValue == null) {
          compare = 1;
        } else if (bValue == null) {
          compare = -1;
        } else if (aValue is num && bValue is num) {
          compare = aValue.compareTo(bValue);
        } else if (aValue is String && bValue is String) {
          compare = aValue.toLowerCase().compareTo(bValue.toLowerCase());
        } else {
          compare = aValue.toString().compareTo(bValue.toString());
        }

        return _sortAscending ? compare : -compare;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedData.isEmpty && widget.emptyMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Text(
            widget.emptyMessage!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.grey[800] : Colors.grey[100];
    final backgroundColor = isDark ? Colors.grey[850] : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          showCheckboxColumn: widget.showCheckboxes,
          columnSpacing: 32,
          horizontalMargin: 24,
          headingRowHeight: 42,
          dataRowHeight: 44,
          dividerThickness: 0.5,
          headingRowColor: MaterialStateProperty.all(headerColor),
          dataRowColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.hovered)) {
              return isDark 
                  ? Colors.grey[800]!.withOpacity(0.5)
                  : Colors.grey[200]!.withOpacity(0.5);
            }
            return backgroundColor;
          }),
          columns: widget.columns.map((column) {
            return DataColumn(
              label: Row(
                children: [
                  Text(
                    column.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (column.tooltip != null) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: column.tooltip!,
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
              numeric: column.numeric,
              onSort: column.sortable
                  ? (columnIndex, ascending) {
                      setState(() {
                        _sortAscending = ascending;
                      });
                      _sortData(widget.columns.indexOf(column));
                    }
                  : null,
            );
          }).toList(),
          rows: _sortedData.map((row) {
            final rowId = row['id']?.toString() ?? '';
            final isSelected = widget.selectedIds.contains(rowId);
            final isHovered = _hoveredRowId == rowId;

            return DataRow(
              selected: isSelected,
              onSelectChanged: widget.showCheckboxes && widget.onSelectionChanged != null
                  ? (selected) {
                      widget.onSelectionChanged!(rowId, selected ?? false);
                    }
                  : null,
              cells: widget.columns.map((column) {
                final value = row[column.key];
                return DataCell(
                  MouseRegion(
                    onEnter: (_) => setState(() => _hoveredRowId = rowId),
                    onExit: (_) => setState(() => _hoveredRowId = null),
                    cursor: widget.onRowTap != null
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    child: column.builder != null
                        ? column.builder!(value, row)
                        : Text(
                            _formatValue(value),
                            style: TextStyle(
                              fontSize: 13,
                              color: isHovered
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                  ),
                  onTap: widget.onRowTap != null
                      ? () => widget.onRowTap!(row)
                      : null,
                );
              }).toList(),
            );
          }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return '--';
    if (value is num) {
      // Format numbers with commas
      if (value is int) {
        return value.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );
      }
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }
}

/// Configuration for a table column
class TableColumn {
  final String key;
  final String label;
  final bool sortable;
  final bool numeric;
  final String? tooltip;
  final Widget Function(dynamic value, Map<String, dynamic> row)? builder;

  const TableColumn({
    required this.key,
    required this.label,
    this.sortable = true,
    this.numeric = false,
    this.tooltip,
    this.builder,
  });
}

