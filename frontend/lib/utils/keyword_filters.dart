import '../providers/project_provider.dart';

/// Helper class for filtering and sorting keywords
class KeywordFilters {
  /// Filter and sort keywords based on search query, filter, and sort options
  static List<TrackedKeyword> filterAndSort(
    List<TrackedKeyword> keywords, {
    required String searchQuery,
    required String filter,
    required String sortBy,
    required bool sortAscending,
  }) {
    // Apply search filter
    List<TrackedKeyword> filtered = keywords;
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((k) => 
        k.keyword.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }
    
    // Apply status filter
    switch (filter) {
      case 'tracking':
        filtered = filtered.where((k) => k.isActive).toList();
        break;
      case 'suggestions':
        filtered = filtered.where((k) => k.isSuggestion).toList();
        break;
      default:
        // Keep all
        break;
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'name':
          comparison = a.keyword.toLowerCase().compareTo(b.keyword.toLowerCase());
          break;
        case 'volume':
          comparison = (b.searchVolume ?? 0).compareTo(a.searchVolume ?? 0);
          break;
        case 'status':
          // Sort by: active first, then suggestions
          if (a.isActive == b.isActive) {
            comparison = 0;
          } else if (a.isActive) {
            comparison = -1;
          } else {
            comparison = 1;
          }
          break;
        case 'position':
        default:
          // Lower position is better, nulls at the end
          if (a.currentPosition == null && b.currentPosition == null) {
            comparison = 0;
          } else if (a.currentPosition == null) {
            comparison = 1;
          } else if (b.currentPosition == null) {
            comparison = -1;
          } else {
            comparison = a.currentPosition!.compareTo(b.currentPosition!);
          }
      }
      
      return sortAscending ? comparison : -comparison;
    });
    
    return filtered;
  }
}

