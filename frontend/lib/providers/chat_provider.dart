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

class ChatProvider with ChangeNotifier {
  List<Message> _messages = [];
  List<Conversation> _conversations = [];
  String? _currentConversationId;
  bool _isLoading = false;
  String _loadingStatus = 'Thinking...';
  List<String> _statusSteps = []; // Track all status steps
  
  // Data panel state
  bool _dataPanelOpen = false;
  List<Map<String, dynamic>> _dataPanelData = [];
  String _dataPanelTitle = '';
  Map<String, List<Map<String, dynamic>>>? _dataPanelTabs;
  String? _dataPanelUrl;
  
  List<Message> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  String? get currentConversationId => _currentConversationId;
  bool get isLoading => _isLoading;
  String get loadingStatus => _loadingStatus;
  List<String> get statusSteps => _statusSteps;
  bool get dataPanelOpen => _dataPanelOpen;
  List<Map<String, dynamic>> get dataPanelData => _dataPanelData;
  String get dataPanelTitle => _dataPanelTitle;
  Map<String, List<Map<String, dynamic>>>? get dataPanelTabs => _dataPanelTabs;
  String? get dataPanelUrl => _dataPanelUrl;
  
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
    _statusSteps = [];
    notifyListeners();
  }
  
  void openDataPanel({required List<Map<String, dynamic>> data, required String title}) {
    _dataPanelOpen = true;
    _dataPanelData = data;
    _dataPanelTitle = title;
    _dataPanelTabs = null; // Clear tabs for single-data view
    _dataPanelUrl = null;
    notifyListeners();
  }
  
  void openTabbedDataPanel({
    required Map<String, List<Map<String, dynamic>>> tabs,
    required String title,
    String? url,
  }) {
    _dataPanelOpen = true;
    _dataPanelTabs = tabs;
    _dataPanelTitle = title;
    _dataPanelUrl = url;
    _dataPanelData = []; // Clear single data for tabbed view
    notifyListeners();
  }
  
  void closeDataPanel() {
    _dataPanelOpen = false;
    _dataPanelTabs = null;
    _dataPanelUrl = null;
    notifyListeners();
  }
}






