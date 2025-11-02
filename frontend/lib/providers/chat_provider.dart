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
  
  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messageCount,
  });
}

class ChatProvider with ChangeNotifier {
  List<Message> _messages = [];
  List<Conversation> _conversations = [];
  String? _currentConversationId;
  bool _isLoading = false;
  String _loadingStatus = 'Thinking...';
  
  List<Message> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  String? get currentConversationId => _currentConversationId;
  bool get isLoading => _isLoading;
  String get loadingStatus => _loadingStatus;
  
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
    notifyListeners();
  }
  
  void startNewConversation() {
    _currentConversationId = null;
    _messages = [];
    notifyListeners();
  }
}



