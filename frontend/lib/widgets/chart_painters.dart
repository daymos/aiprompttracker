import 'package:flutter/material.dart';

class NoDataSparklinePainter extends CustomPainter {
  final Color lineColor;

  NoDataSparklinePainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw a dashed horizontal line in the middle
    final y = size.height / 2;
    final dashWidth = 4.0;
    final dashSpace = 4.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(NoDataSparklinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class PerformanceChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> dataPoints;
  final bool showDomainAuthority;
  final bool showReferringDomains;
  final bool showOrganicTraffic;
  
  PerformanceChartPainter({
    required this.dataPoints,
    required this.showDomainAuthority,
    required this.showReferringDomains,
    required this.showOrganicTraffic,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;
    
    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    
    // Draw grid lines
    _drawGrid(canvas, size, padding);
    
    // Draw each metric line
    if (showDomainAuthority) {
      _drawMetricLine(canvas, size, padding, chartWidth, chartHeight, 'da', Colors.purple[400]!, 0, 100);
    }
    
    if (showReferringDomains) {
      final maxRD = dataPoints.map((p) => (p['referring_domains'] ?? 0) as num).reduce((a, b) => a > b ? a : b).toDouble();
      _drawMetricLine(canvas, size, padding, chartWidth, chartHeight, 'referring_domains', Colors.blue[400]!, 0, maxRD * 1.1);
    }
    
    if (showOrganicTraffic && dataPoints.any((p) => p['clicks'] != null)) {
      final maxClicks = dataPoints.where((p) => p['clicks'] != null).map((p) => (p['clicks'] ?? 0) as num).reduce((a, b) => a > b ? a : b).toDouble();
      if (maxClicks > 0) {
        _drawMetricLine(canvas, size, padding, chartWidth, chartHeight, 'clicks', Colors.orange[400]!, 0, maxClicks * 1.1);
      }
    }
    
    // Draw date labels
    _drawDateLabels(canvas, size, padding, chartWidth, chartHeight);
  }
  
  void _drawGrid(Canvas canvas, Size size, double padding) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    
    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = padding + (size.height - padding * 2) * i / 4;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        paint,
      );
    }
  }
  
  void _drawMetricLine(Canvas canvas, Size size, double padding, double chartWidth, double chartHeight, String key, Color color, double minValue, double maxValue) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    bool firstPoint = true;
    
    for (int i = 0; i < dataPoints.length; i++) {
      final point = dataPoints[i];
      final value = point[key];
      
      if (value == null) continue;
      
      final x = padding + (chartWidth * i / (dataPoints.length - 1));
      final normalizedValue = (value - minValue) / (maxValue - minValue);
      final y = padding + chartHeight - (normalizedValue * chartHeight);
      
      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
      
      // Draw dot
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = color..style = PaintingStyle.fill,
      );
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawDateLabels(Canvas canvas, Size size, double padding, double chartWidth, double chartHeight) {
    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10,
    );
    
    // Show first, middle, and last dates
    final indices = [0, dataPoints.length ~/ 2, dataPoints.length - 1];
    
    for (final i in indices) {
      if (i >= dataPoints.length) continue;
      
      final date = dataPoints[i]['date'] as DateTime;
      final label = '${date.day} ${_getMonthName(date.month)}';
      
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final x = padding + (chartWidth * i / (dataPoints.length - 1)) - textPainter.width / 2;
      final y = size.height - padding + 10;
      
      textPainter.paint(canvas, Offset(x, y));
    }
  }
  
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  bool shouldRepaint(PerformanceChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
           oldDelegate.showDomainAuthority != showDomainAuthority ||
           oldDelegate.showReferringDomains != showReferringDomains ||
           oldDelegate.showOrganicTraffic != showOrganicTraffic;
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> positions;
  final Color lineColor;
  final bool invertY; // If true, lower values are better (rankings). If false, higher is better (metrics)

  SparklinePainter(this.positions, this.lineColor, {this.invertY = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Find min and max for scaling
    final minPos = positions.reduce((a, b) => a < b ? a : b);
    final maxPos = positions.reduce((a, b) => a > b ? a : b);
    final range = maxPos - minPos;

    if (range == 0) {
      // All positions are the same, draw a flat line
      final y = size.height / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
      return;
    }

    final path = Path();
    for (int i = 0; i < positions.length; i++) {
      final x = (i / (positions.length - 1)) * size.width;
      final normalizedPos = (positions[i] - minPos) / range;
      
      // For invertY=true (rankings): lower position (1) should be at top (small Y)
      // For invertY=false (metrics): higher value should be at top (small Y)
      final y = invertY 
          ? normalizedPos * size.height  // Lower value = top
          : (1 - normalizedPos) * size.height;  // Higher value = top

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) {
    return oldDelegate.positions != positions || oldDelegate.lineColor != lineColor;
  }
}

// Line chart painter for overview tab
class LineChartPainter extends CustomPainter {
  final List data;
  final Color color;
  final String dataKey;
  final String Function(double) labelFormatter;

  LineChartPainter({
    required this.data,
    required this.color,
    required this.dataKey,
    required this.labelFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Find min and max values
    final values = data.map((d) => (d[dataKey] ?? 0).toDouble()).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;

    // Handle flat line case
    final effectiveRange = range == 0 ? 1.0 : range;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw the line chart
    final path = Path();
    final fillPath = Path();
    
    fillPath.moveTo(0, size.height);
    
    for (int i = 0; i < data.length; i++) {
      final value = (data[i][dataKey] ?? 0).toDouble();
      final x = size.width * i / (data.length - 1);
      final y = size.height - ((value - minValue) / effectiveRange * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final value = (data[i][dataKey] ?? 0).toDouble();
      final x = size.width * i / (data.length - 1);
      final y = size.height - ((value - minValue) / effectiveRange * size.height);
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
