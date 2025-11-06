import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class KeywordDetailScreen extends StatefulWidget {
  final String keywordId;
  final String keyword;
  final int? currentPosition;

  const KeywordDetailScreen({
    super.key,
    required this.keywordId,
    required this.keyword,
    required this.currentPosition,
  });

  @override
  State<KeywordDetailScreen> createState() => _KeywordDetailScreenState();
}

class _KeywordDetailScreenState extends State<KeywordDetailScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await authProvider.apiService.getKeywordHistory(widget.keywordId);
      setState(() {
        _history = List<Map<String, dynamic>>.from(response['history']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.keyword),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No ranking history yet'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildStatColumn(
                                      'Current Position',
                                      widget.currentPosition?.toString() ?? 'Not Ranked',
                                      widget.currentPosition != null
                                          ? _getPositionColor(widget.currentPosition!)
                                          : Colors.grey,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildStatColumn(
                                      '7-Day Change',
                                      _get7DayChange(),
                                      _get7DayChange().startsWith('+')
                                          ? Colors.red
                                          : _get7DayChange().startsWith('-')
                                              ? Colors.green
                                              : Colors.grey,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildStatColumn(
                                      'Best Position',
                                      _getBestPosition(),
                                      Colors.green,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildStatColumn(
                                      'Checks',
                                      _history.length.toString(),
                                      Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Chart
                          Text(
                            'Ranking History',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: SizedBox(
                                height: 300,
                                child: _buildChart(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Data Table
                          Text(
                            'All Checks',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildDataTable(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_history.isEmpty) return const Center(child: Text('No data'));

    // Prepare data points (reverse to show oldest first)
    final spots = <FlSpot>[];
    for (var i = 0; i < _history.length; i++) {
      final position = _history[i]['position'];
      if (position != null) {
        spots.add(FlSpot(i.toDouble(), position.toDouble()));
      }
    }

    if (spots.isEmpty) return const Center(child: Text('No ranked positions yet'));

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 10,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Position'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Days Ago'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _history.length) return const Text('');
                
                final date = DateTime.parse(_history[index]['checked_at']);
                final daysAgo = DateTime.now().difference(date).inDays;
                return Text(
                  daysAgo == 0 ? 'Today' : '${daysAgo}d',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.deepPurple,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.deepPurple,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.deepPurple.withOpacity(0.1),
            ),
          ),
        ],
        // Invert Y-axis (position 1 at top, 100 at bottom)
        minY: 0,
        maxY: 100,
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Position')),
          DataColumn(label: Text('Change')),
          DataColumn(label: Text('Page URL')),
        ],
        rows: _history.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final position = item['position'];
          final prevPosition = index > 0 ? _history[index - 1]['position'] : null;
          
          final change = position != null && prevPosition != null
              ? prevPosition - position
              : null;
          
          final date = DateTime.parse(item['checked_at']);
          final pageUrl = item['page_url'] ?? '--';

          return DataRow(cells: [
            DataCell(Text(_formatDate(date))),
            DataCell(Text(
              position?.toString() ?? 'Not Ranked',
              style: TextStyle(
                color: position != null ? _getPositionColor(position) : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            )),
            DataCell(Text(
              change != null
                  ? '${change > 0 ? '↗️ +' : change < 0 ? '↘️ ' : '➡️ '}$change'
                  : '--',
              style: TextStyle(
                color: change != null && change > 0
                    ? Colors.green
                    : change != null && change < 0
                        ? Colors.red
                        : Colors.grey,
              ),
            )),
            DataCell(
              Text(
                pageUrl.length > 30 ? '${pageUrl.substring(0, 30)}...' : pageUrl,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  String _get7DayChange() {
    if (_history.length < 2) return '--';
    
    final current = _history.last['position'];
    if (current == null) return '--';
    
    // Find position from ~7 days ago
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    Map<String, dynamic>? weekAgoData;
    
    for (var item in _history.reversed) {
      final date = DateTime.parse(item['checked_at']);
      if (date.isBefore(weekAgo) && item['position'] != null) {
        weekAgoData = item;
        break;
      }
    }
    
    if (weekAgoData == null) return '--';
    
    final change = weekAgoData['position'] - current;
    return change > 0 ? '-$change' : change < 0 ? '+${change.abs()}' : '0';
  }

  String _getBestPosition() {
    int? best;
    for (var item in _history) {
      final pos = item['position'];
      if (pos != null && (best == null || pos < best)) {
        best = pos;
      }
    }
    return best?.toString() ?? '--';
  }

  Color _getPositionColor(int position) {
    if (position <= 3) return Colors.green;
    if (position <= 10) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    
    return '${date.month}/${date.day}/${date.year}';
  }
}






