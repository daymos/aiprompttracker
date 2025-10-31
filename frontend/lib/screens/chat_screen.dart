import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/conversation_list.dart';
import 'dart:html' as html;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showConversations = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _downloadConversationAsCSV() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (chatProvider.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to export')),
      );
      return;
    }
    
    // Build CSV content
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Role,Message');
    
    for (final message in chatProvider.messages) {
      // Escape quotes and newlines for CSV
      final content = message.content
          .replaceAll('"', '""')
          .replaceAll('\n', ' ')
          .replaceAll('\r', '');
      
      buffer.writeln('${message.createdAt.toIso8601String()},${message.role},"$content"');
    }
    
    // Create download with proper text encoding
    final csvContent = buffer.toString();
    final blob = html.Blob([csvContent], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'conversation_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conversation exported to CSV')),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();

    // Add user message immediately
    chatProvider.addMessage(Message(
      id: DateTime.now().toString(),
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
    ));
    
    _messageController.clear();
    _scrollToBottom();

    chatProvider.setLoading(true);

    try {
      final response = await authProvider.apiService.sendMessage(
        message,
        chatProvider.currentConversationId,
      );

      chatProvider.setCurrentConversation(response['conversation_id']);
      chatProvider.addMessage(Message(
        id: DateTime.now().toString(),
        role: 'assistant',
        content: response['message'],
        createdAt: DateTime.now(),
      ));

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      chatProvider.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.network(
              '/logo-icon.svg',
              height: 32,
              width: 32,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.search, size: 24);
              },
            ),
            const SizedBox(width: 12),
            const Text('KeywordsChat'),
          ],
        ),
        leading: IconButton(
          icon: Icon(_showConversations ? Icons.close : Icons.menu),
          onPressed: () {
            setState(() {
              _showConversations = !_showConversations;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.track_changes),
            onPressed: () {
              Navigator.pushNamed(context, '/project');
            },
            tooltip: 'My Projects',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: chatProvider.messages.isEmpty ? null : _downloadConversationAsCSV,
            tooltip: 'Download as CSV',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              chatProvider.startNewConversation();
              MessageBubble.clearAnimationCache();
              setState(() {
                _showConversations = false;
              });
            },
            tooltip: 'New conversation',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(authProvider.name ?? authProvider.email ?? 'User'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'),
                  dense: true,
                ),
                onTap: () async {
                  await authProvider.signOut();
                },
              ),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // Conversation list sidebar
          if (_showConversations)
            SizedBox(
              width: 300,
              child: ConversationList(
                onConversationSelected: (conversationId) async {
                  // Load the conversation messages
                  setState(() {
                    _showConversations = false;
                  });
                  
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                  
                  chatProvider.setLoading(true);
                  
                  try {
                    final conversationData = await authProvider.apiService.getConversation(conversationId);
                    
                    // Load messages
                    final messages = (conversationData['messages'] as List).map((m) => Message(
                      id: m['id'],
                      role: m['role'],
                      content: m['content'],
                      createdAt: DateTime.parse(m['created_at']),
                    )).toList();
                    
                    chatProvider.setCurrentConversation(conversationId);
                    chatProvider.setMessages(messages);
                    
                    // Scroll to bottom
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
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
              ),
            ),
          
          // Main chat area
          Expanded(
            child: chatProvider.messages.isEmpty
                ? _buildEmptyStateWithInput()
                : Column(
                    children: [
                      // Messages
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          itemCount: chatProvider.messages.length,
                          itemBuilder: (context, index) {
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 900),
                                child: MessageBubble(
                                  message: chatProvider.messages[index],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Loading indicator
                      if (chatProvider.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: LinearProgressIndicator(),
                        ),
                      
                      // Input area (bottom)
                      _buildInputArea(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWithInput() {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.name?.split(' ').first ?? 'there';
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and Greeting
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      '/logo.svg',
                      height: 80,
                      width: 80,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.search, size: 64);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.waving_hand,
                        size: 28,
                        color: Colors.orange[300],
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Hello, $userName',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              
              // Centered input
              TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ask about keywords for your content...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.arrow_upward),
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Ask about keywords...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.arrow_upward),
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
      ),
    );
  }
}

