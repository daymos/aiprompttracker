/// Helper class for filtering and sorting backlinks
class BacklinkFilters {
  /// Filter and sort backlinks based on search query, filter type, and sort options
  static List<Map<String, dynamic>> filterAndSort(
    List<Map<String, dynamic>> backlinks, {
    required String searchQuery,
    required String filter,
    required String sortBy,
    required bool sortAscending,
  }) {
    // Apply search filter (search in source URL and anchor text)
    List<Map<String, dynamic>> filtered = backlinks;
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((b) {
        final sourceUrl = (b['url_from'] as String? ?? '').toLowerCase();
        final anchorText = (b['anchor'] as String? ?? '').toLowerCase();
        return sourceUrl.contains(query) || anchorText.contains(query);
      }).toList();
    }
    
    // Apply link type filter
    switch (filter) {
      case 'follow':
        filtered = filtered.where((b) => b['nofollow'] != true).toList();
        break;
      case 'nofollow':
        filtered = filtered.where((b) => b['nofollow'] == true).toList();
        break;
      default:
        // Keep all
        break;
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'anchor':
          final aAnchor = (a['anchor'] as String? ?? '').toLowerCase();
          final bAnchor = (b['anchor'] as String? ?? '').toLowerCase();
          comparison = aAnchor.compareTo(bAnchor);
          break;
        case 'source':
          final aSource = (a['url_from'] as String? ?? '').toLowerCase();
          final bSource = (b['url_from'] as String? ?? '').toLowerCase();
          comparison = aSource.compareTo(bSource);
          break;
        case 'rank':
        default:
          // Sort by inlink rank (higher is better)
          final aRank = a['inlink_rank'] as num? ?? 0;
          final bRank = b['inlink_rank'] as num? ?? 0;
          comparison = bRank.compareTo(aRank); // Higher rank first by default
      }
      
      return sortAscending ? comparison : -comparison;
    });
    
    return filtered;
  }
}
