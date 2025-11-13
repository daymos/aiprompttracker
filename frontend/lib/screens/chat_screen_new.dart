import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/project_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/theme_switcher.dart';
import '../widgets/grid_pattern_background.dart';
import 'dart:html' as html;
import 'dart:async';

// Import extracted widgets
import 'chat/welcome_screen.dart';
import 'chat/chat_input_area.dart';
import 'chat/conversations_view.dart';
import 'projects/project_list_view.dart';

// Import the full project detail logic (kept as-is for now)
import 'projects/project_detail_delegate.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum ViewState { chat, conversations, projects }

class _ChatScreenState extends State<ChatScreen> with ProjectDetailDelegate {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _hasLoadedProjects = false;
  bool _shouldCancelRequest = false;
  ViewState _currentView = ViewState.chat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedProjects) {
        final authProvider = context.read<AuthProvider>();
        final projectProvider = context.read<ProjectProvider>();
        projectProvider.loadAllProjects(authProvider.apiService);
        _hasLoadedProjects = true;
      }

      final chatProvider = context.read<ChatProvider>();
      chatProvider.addListener(_scrollToBottom);
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _currentView == ViewState.chat) {
          _messageFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.removeListener(_scrollToBottom);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    disposeProjectDetail();
    super.dispose();
  }

  void _switchToChatView() {
    setState(() {
      _currentView = ViewState.chat;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _currentView == ViewState.chat) {
        _messageFocusNode.requestFocus();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    
    if (_messageController.text.trim().isEmpty || chatProvider.isLoading) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();
    _shouldCancelRequest = false;

    try {
      await chatProvider.sendMessage(messageText, authProvider.apiService,
          shouldCancel: () => _shouldCancelRequest);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _stopGeneration() {
    setState(() {
      _shouldCancelRequest = true;
    });
  }

  void _downloadConversationAsCSV() {
    final chatProvider = context.read<ChatProvider>();
    
    if (chatProvider.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to export')),
      );
      return;
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Role,Message');
    
    for (final message in chatProvider.messages) {
      final content = message.content
          .replaceAll('"', '""')
          .replaceAll('\n', ' ')
          .replaceAll('\r', '');
      final timestamp = message.createdAt.toIso8601String();
      buffer.writeln('"$timestamp","${message.role}","$content"');
    }
    
    final conversationId = chatProvider.currentConversationId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final blob = html.Blob([buffer.toString()], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'conversation_$conversationId.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      body: GridPatternBackground(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Logo/Title
                  TextButton(
                    onPressed: () => _switchToChatView(),
                    child: Row(
                      children: [
                        Text(
                          'Keywords',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4FC3F7),
                          ),
                        ),
                        Text(
                          '.chat',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Nav buttons
                  IconButton(
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: _currentView == ViewState.chat
                          ? const Color(0xFF4FC3F7)
                          : null,
                    ),
                    onPressed: () => _switchToChatView(),
                    tooltip: 'Chat',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.history,
                      color: _currentView == ViewState.conversations
                          ? const Color(0xFF4FC3F7)
                          : null,
                    ),
                    onPressed: () => setState(() => _currentView = ViewState.conversations),
                    tooltip: 'Conversations',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.track_changes,
                      color: _currentView == ViewState.projects
                          ? const Color(0xFF4FC3F7)
                          : null,
                    ),
                    onPressed: () => setState(() => _currentView = ViewState.projects),
                    tooltip: 'Projects',
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    onPressed: _downloadConversationAsCSV,
                    tooltip: 'Export as CSV',
                  ),
                  const ThemeSwitcher(),
                ],
              ),
            ),

            // Main content area
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentView) {
      case ViewState.chat:
        return _buildChatView();
      case ViewState.conversations:
        return _buildConversationsView();
      case ViewState.projects:
        return _buildProjectsView();
    }
  }

  Widget _buildChatView() {
    final chatProvider = context.watch<ChatProvider>();
    
    return Column(
      children: [
        // Messages area
        Expanded(
          child: chatProvider.messages.isEmpty
              ? WelcomeScreen(
                  messageController: _messageController,
                  onSendMessage: _sendMessage,
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(message: chatProvider.messages[index]);
                  },
                ),
        ),
        // Input area
        ChatInputArea(
          messageController: _messageController,
          messageFocusNode: _messageFocusNode,
          onSendMessage: _sendMessage,
          onCancelRequest: _stopGeneration,
          shouldCancelRequest: _shouldCancelRequest,
        ),
      ],
    );
  }

  Widget _buildConversationsView() {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    
    return ConversationsView(
      onConversationSelected: (conversationId) async {
        chatProvider.setLoading(true);
        
        try {
          final conversationData = await authProvider.apiService.getConversation(conversationId);
          
          final messages = (conversationData['messages'] as List).map((m) => Message(
            id: m['id'],
            role: m['role'],
            content: m['content'],
            createdAt: DateTime.parse(m['created_at']),
            messageMetadata: m['message_metadata'] as Map<String, dynamic>?,
          )).toList();
          
          chatProvider.setCurrentConversation(conversationId);
          chatProvider.setMessages(messages);
          
          _switchToChatView();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading conversation: $e')),
            );
          }
        } finally {
          chatProvider.setLoading(false);
        }
      },
    );
  }

  Widget _buildProjectsView() {
    return buildProjectsView(context, setState);
  }
}

