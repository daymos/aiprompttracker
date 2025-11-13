import 'package:flutter/material.dart';

/// SEO-specific color helpers for rankings, scores, and metrics
class ColorHelpers {
  /// Get color for average ranking position (lower is better)
  static Color getAvgRankingColor(double avgPosition) {
    if (avgPosition <= 3) return Colors.green[600]!;
    if (avgPosition <= 10) return Colors.blue[600]!;
    if (avgPosition <= 20) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  /// Get color for domain authority score (0-100)
  static Color getDomainAuthorityColor(int da) {
    if (da >= 70) return Colors.green[600]!;
    if (da >= 50) return Colors.blue[600]!;
    if (da >= 30) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  /// Get color for SEO difficulty score (0-100)
  static Color getSeoDifficultyColor(int difficulty) {
    if (difficulty < 30) return Colors.green[600]!;  // Easy
    if (difficulty < 60) return Colors.orange[600]!; // Moderate
    return Colors.red[600]!;  // Hard
  }

  /// Get color for spam score (0-100, lower is better)
  static Color getSpamScoreColor(int score) {
    if (score >= 60) return Colors.red[600]!;
    if (score >= 30) return Colors.orange[600]!;
    if (score >= 10) return Colors.yellow[700]!;
    return Colors.green[600]!;
  }

  /// Get color for average position (lower is better)
  static Color getAvgPositionColor(double avgPosition) {
    if (avgPosition <= 3) return Colors.green[600]!;
    if (avgPosition <= 10) return Colors.blue[600]!;
    if (avgPosition <= 20) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  /// Get color for performance score (0-100, higher is better)
  static Color getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  /// Get color for status string (sitemap/indexing statuses and content statuses)
  static Color getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    switch (status.toLowerCase()) {
      // Content statuses (SEO Agent)
      case 'published':
        return const Color(0xFF4CAF50);
      case 'scheduled':
        return const Color(0xFF2196F3);
      case 'draft':
        return const Color(0xFF9E9E9E);
      
      // GSC/Sitemap statuses
      case 'submitted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'indexed':
        return Colors.blue;
      case 'approved':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      
      default:
        return Colors.grey;
    }
  }

  /// Get color for keyword position (lower is better)
  static Color getPositionColor(int? position) {
    if (position == null) return Colors.grey;
    if (position <= 3) return Colors.green;
    if (position <= 10) return Colors.orange;
    return Colors.red;
  }
}
