/// Simple formatting utilities for numbers and dates
class FormattingUtils {
  /// Format a number with K/M suffix (e.g., 1000 -> "1.0K")
  static String formatNumber(dynamic value) {
    if (value == null) return '0';
    final number = value is num ? value : 0;
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Format an ISO date string to relative time (e.g., "2 days ago")
  static String formatAnalyzedDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateStr;
    }
  }

  /// Get a clean preview of content by stripping markdown and limiting length
  static String getContentPreview(String content, {int maxLength = 100}) {
    if (content.isEmpty) return 'No content';

    // Clean up the content for preview
    // Remove markdown formatting and extra whitespace
    var preview = content
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')     // Remove italic
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')     // Remove inline code
        .replaceAll(RegExp(r'#+\s*'), '')            // Remove headers
        .replaceAll(RegExp(r'\n+'), ' ')             // Replace newlines with spaces
        .trim();

    // Limit to reasonable length for preview
    if (preview.length > maxLength) {
      preview = '${preview.substring(0, maxLength - 3)}...';
    }

    return preview.isEmpty ? 'No content' : preview;
  }

  /// Format a DateTime to a user-friendly relative string
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
