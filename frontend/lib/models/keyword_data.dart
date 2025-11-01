class KeywordData {
  final String keyword;
  final int? searchVolume;
  final String? competition;
  
  KeywordData({
    required this.keyword,
    this.searchVolume,
    this.competition,
  });
  
  static List<KeywordData> parseFromMessage(String content) {
    final keywords = <KeywordData>[];
    
    // Pattern 1: Bullet points with data: "• keyword (volume/mo, competition)"
    final bulletPattern = RegExp(
      r'[•\-\*]\s*["\"]?([^""\(\n]+?)["\"]?\s*\(([0-9,]+)(?:/mo)?[,\s]+([A-Z]+)',
      multiLine: true,
      caseSensitive: false
    );
    
    for (final match in bulletPattern.allMatches(content)) {
      keywords.add(KeywordData(
        keyword: match.group(1)!.trim(),
        searchVolume: int.tryParse(match.group(2)!.replaceAll(',', '')),
        competition: match.group(3)!.toUpperCase(),
      ));
    }
    
    // Pattern 2: Table format detection
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Look for table rows with | separators
      if (line.contains('|') && !line.startsWith('|---')) {
        final cells = line.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        
        if (cells.length >= 3) {
          // Skip header rows
          if (cells[0].toLowerCase().contains('keyword') || 
              cells[1].toLowerCase().contains('search')) {
            continue;
          }
          
          // Try to parse keyword, volume, competition
          final keyword = cells[0].trim();
          final volumeStr = cells[1].replaceAll(RegExp(r'[^0-9]'), '');
          final competition = cells.length > 2 ? cells[2].toUpperCase() : null;
          
          if (keyword.isNotEmpty && volumeStr.isNotEmpty) {
            keywords.add(KeywordData(
              keyword: keyword,
              searchVolume: int.tryParse(volumeStr),
              competition: competition,
            ));
          }
        }
      }
    }
    
    return keywords;
  }
}



