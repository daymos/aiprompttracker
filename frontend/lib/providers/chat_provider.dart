import 'package:flutter/material.dart';

class Message {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? messageMetadata;
  
  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.messageMetadata,
  });
}

class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final int messageCount;
  final List<String> projectNames;
  
  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messageCount,
    this.projectNames = const [],
  });
}

class ConversationResult {
  final String id;
  final String title;
  final String type; // 'keywords', 'rankings', 'technical_audit', etc.
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  
  ConversationResult({
    required this.id,
    required this.title,
    required this.type,
    required this.data,
    required this.timestamp,
    this.metadata,
  });
}

class ChatProvider with ChangeNotifier {
  List<Message> _messages = [];
  List<Conversation> _conversations = [];
  String? _currentConversationId;
  bool _isLoading = false;
  String _loadingStatus = 'Thinking...';
  List<String> _statusSteps = []; // Track all status steps
  
  // Data panel state
  bool _dataPanelOpen = false;
  bool _dataPanelMinimized = false;
  List<Map<String, dynamic>> _dataPanelData = [];
  String _dataPanelTitle = '';
  Map<String, List<Map<String, dynamic>>>? _dataPanelTabs;
  String? _dataPanelUrl;
  
  // Conversation results accumulator
  Map<String, ConversationResult> _conversationResults = {};
  List<String> _conversationResultOrder = [];
  
  List<Message> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  String? get currentConversationId => _currentConversationId;
  bool get isLoading => _isLoading;
  String get loadingStatus => _loadingStatus;
  List<String> get statusSteps => _statusSteps;
  bool get dataPanelOpen => _dataPanelOpen;
  bool get dataPanelMinimized => _dataPanelMinimized;
  List<Map<String, dynamic>> get dataPanelData => _dataPanelData;
  String get dataPanelTitle => _dataPanelTitle;
  Map<String, List<Map<String, dynamic>>>? get dataPanelTabs => _dataPanelTabs;
  String? get dataPanelUrl => _dataPanelUrl;
  Map<String, ConversationResult> get conversationResults => _conversationResults;
  List<String> get conversationResultOrder => _conversationResultOrder;
  
  void addMessage(Message message) {
    _messages.add(message);
    notifyListeners();
  }
  
  void setMessages(List<Message> messages) {
    _messages = messages;
    notifyListeners();
  }
  
  void setConversations(List<Conversation> conversations) {
    _conversations = conversations;
    notifyListeners();
  }
  
  void setCurrentConversation(String? id) {
    _currentConversationId = id;
    if (id == null) {
      _messages = [];
      _conversationResults = {};
      _conversationResultOrder = [];
    }
    notifyListeners();
  }
  
  void setLoading(bool loading, {String status = 'Thinking...'}) {
    _isLoading = loading;
    _loadingStatus = status;
    
    // If starting to load and status is new, add it to the steps
    if (loading && !_statusSteps.contains(status)) {
      _statusSteps.add(status);
    }
    
    // If done loading, clear status steps
    if (!loading) {
      _statusSteps = [];
    }
    
    notifyListeners();
  }
  
  void startNewConversation() {
    _currentConversationId = null;
    _messages = [];
    _dataPanelOpen = false;
    _dataPanelMinimized = false;
    _statusSteps = [];
    _conversationResults = {};
    _conversationResultOrder = [];
    notifyListeners();
  }
  
  void openDataPanel({
    required List<Map<String, dynamic>> data, 
    required String title,
    String? type,
    Map<String, dynamic>? metadata,
  }) {
    // Add this result to the conversation results
    final resultId = 'result_${DateTime.now().millisecondsSinceEpoch}';
    final result = ConversationResult(
      id: resultId,
      title: title,
      type: type ?? 'data',
      data: data,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    
    _conversationResults[resultId] = result;
    _conversationResultOrder.add(resultId);
    
    // Build tabs from all conversation results
    _rebuildDataPanelTabs();
    
    _dataPanelOpen = true;
    _dataPanelMinimized = false;
    _dataPanelTitle = 'Conversation Results';
    notifyListeners();
  }
  
  void openTabbedDataPanel({
    required Map<String, List<Map<String, dynamic>>> tabs,
    required String title,
    String? url,
  }) {
    // For technical audits with multiple tabs, add as a single result with subtabs
    final resultId = 'result_${DateTime.now().millisecondsSinceEpoch}';
    final result = ConversationResult(
      id: resultId,
      title: title,
      type: 'technical_audit',
      data: [], // Technical audits use tabs, not flat data
      timestamp: DateTime.now(),
      metadata: {'tabs': tabs, 'url': url},
    );
    
    _conversationResults[resultId] = result;
    _conversationResultOrder.add(resultId);
    
    // Build tabs from all conversation results
    _rebuildDataPanelTabs();
    
    _dataPanelOpen = true;
    _dataPanelMinimized = false;
    _dataPanelTitle = 'Conversation Results';
    _dataPanelUrl = url;
    notifyListeners();
  }
  
  void _rebuildDataPanelTabs() {
    // Build tabs from all conversation results in order
    _dataPanelTabs = {};
    
    // Count occurrences of each type to add numbers
    final Map<String, int> typeCounts = {};
    
    for (final resultId in _conversationResultOrder) {
      final result = _conversationResults[resultId];
      if (result == null) continue;
      
      // Use a shortened title for the tab
      String baseLabel = result.title;
      
      // Shorten common titles
      if (baseLabel.startsWith('Keyword Research Results')) {
        baseLabel = 'Keywords';
      } else if (baseLabel.startsWith('Ranking Report')) {
        baseLabel = 'Rankings';
      } else if (baseLabel.startsWith('Technical SEO')) {
        baseLabel = 'Tech SEO';
      } else if (baseLabel.contains('Audit')) {
        baseLabel = 'Audit';
      } else if (baseLabel.length > 30) {
        // Truncate long titles
        baseLabel = '${baseLabel.substring(0, 27)}...';
      }
      
      // Add number suffix if we have multiple of the same type
      typeCounts[baseLabel] = (typeCounts[baseLabel] ?? 0) + 1;
      final count = typeCounts[baseLabel]!;
      
      // Create unique label by adding count if needed
      String tabLabel = baseLabel;
      if (count > 1 || _conversationResultOrder.where((id) {
        final r = _conversationResults[id];
        if (r == null) return false;
        String checkLabel = r.title;
        if (checkLabel.startsWith('Keyword Research Results')) checkLabel = 'Keywords';
        else if (checkLabel.startsWith('Ranking Report')) checkLabel = 'Rankings';
        else if (checkLabel.startsWith('Technical SEO')) checkLabel = 'Tech SEO';
        else if (checkLabel.contains('Audit')) checkLabel = 'Audit';
        return checkLabel == baseLabel;
      }).length > 1) {
        tabLabel = '$baseLabel #$count';
      }
      
      _dataPanelTabs![tabLabel] = result.data;
    }
    
    // If we only have one result, also set the single data view
    if (_conversationResults.length == 1) {
      _dataPanelData = _conversationResults.values.first.data;
    } else {
      _dataPanelData = [];
    }
  }
  
  void closeDataPanel() {
    _dataPanelOpen = false;
    _dataPanelMinimized = false;
    // Keep the tabs and results data for reopening
    notifyListeners();
  }
  
  void minimizeDataPanel() {
    _dataPanelMinimized = true;
    notifyListeners();
  }
  
  void maximizeDataPanel() {
    _dataPanelMinimized = false;
    notifyListeners();
  }
  
  void reopenDataPanel() {
    if (_conversationResults.isEmpty) return;
    
    // Rebuild tabs from conversation results
    _rebuildDataPanelTabs();
    
    _dataPanelOpen = true;
    _dataPanelMinimized = false;
    _dataPanelTitle = 'Conversation Results';
    notifyListeners();
  }
  
  bool get hasConversationResults => _conversationResults.isNotEmpty;
}






