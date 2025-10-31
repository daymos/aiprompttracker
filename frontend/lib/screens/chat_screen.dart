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
  bool _hasShownWelcomeModal = false;

  @override
  void initState() {
    super.initState();
    // Show welcome modal after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownWelcomeModal) {
        _showWelcomeModal();
        _hasShownWelcomeModal = true;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showWelcomeModal() {
    final chatProvider = context.read<ChatProvider>();
    
    // Only show if this is truly the first visit (no messages)
    if (chatProvider.messages.isNotEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Want to start with a guided conversation about SEO?',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _messageController.text = 'Yes, show me what keywords.chat can do for me. I\'d like to understand all the features and how you can help with my SEO.';
                _sendMessage();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: const Text('Yes, show me what keywords.chat can do for me'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No thanks, I\'ll explore on my own'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuidesModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Guided Conversations',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGuideButton(
                'What can Keywords.chat do?',
                'What can keywords.chat do for me? I\'d like to understand all the features and how you can help with my SEO.',
                Icons.info_outline,
              ),
              const SizedBox(height: 12),
              _buildGuideButton(
                'Track keywords',
                'I want to track keywords for my website. Can you help me set up keyword tracking and monitoring?',
                Icons.track_changes,
              ),
              const SizedBox(height: 12),
              _buildGuideButton(
                'Analyze my website',
                'I want to analyze my website for SEO opportunities. Can you help me understand what keywords I should target?',
                Icons.search,
              ),
              const SizedBox(height: 12),
              _buildGuideButton(
                'Find keyword ideas',
                'I need help finding keyword ideas for my niche. What should I be ranking for?',
                Icons.lightbulb_outline,
              ),
              const SizedBox(height: 12),
              _buildGuideButton(
                'Understand keyword difficulty',
                'Can you explain keyword difficulty and help me find keywords I can actually rank for?',
                Icons.analytics_outlined,
              ),
              const SizedBox(height: 12),
              _buildGuideButton(
                'Create an SEO strategy',
                'I\'m new to SEO. Can you help me create a keyword strategy for my website?',
                Icons.map_outlined,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideButton(String title, String prompt, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.pop(context);
        _messageController.text = prompt;
        _sendMessage();
      },
      icon: Icon(icon, size: 20),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(title),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
      ),
    );
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
        toolbarHeight: 0,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Persistent left sidebar with icons
          Container(
            width: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'K',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // New conversation button
                IconButton(
                  onPressed: () {
                    chatProvider.startNewConversation();
                    MessageBubble.clearAnimationCache();
                    setState(() {
                      _showConversations = false;
                    });
                  },
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  tooltip: 'New conversation',
                ),
                const SizedBox(height: 12),
                // Conversations toggle
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showConversations = !_showConversations;
                    });
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  style: IconButton.styleFrom(
                    backgroundColor: _showConversations 
                      ? Theme.of(context).colorScheme.secondaryContainer 
                      : Colors.transparent,
                  ),
                  tooltip: 'Conversations',
                ),
                const SizedBox(height: 12),
                // Projects button
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/project');
                  },
                  icon: const Icon(Icons.track_changes),
                  tooltip: 'My Projects',
                ),
                const SizedBox(height: 12),
                // Guides button
                IconButton(
                  onPressed: _showGuidesModal,
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Guides',
                ),
                const Spacer(),
                // User menu at bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PopupMenuButton<String>(
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      radius: 18,
                      child: Text(
                        (authProvider.name?.substring(0, 1) ?? authProvider.email?.substring(0, 1) ?? 'U').toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        enabled: false,
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(authProvider.name ?? authProvider.email ?? 'User'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'signout',
                        child: ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Sign out'),
                          dense: true,
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'signout') {
                        await authProvider.signOut();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Expandable conversation list
          if (_showConversations)
            SizedBox(
              width: 280,
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
    final chatProvider = context.watch<ChatProvider>();
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Column(
                children: [
                  Text(
                    'Welcome to Keywords.chat',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SEO tools via chatbot',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 64),
              
              // Centered input
              TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Let\'s talk about SEO for your website...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Download CSV button
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: chatProvider.messages.isEmpty
                                ? Theme.of(context).colorScheme.surfaceVariant
                                : Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: chatProvider.messages.isEmpty ? null : _downloadConversationAsCSV,
                            icon: const Icon(Icons.download),
                            iconSize: 16,
                            padding: EdgeInsets.zero,
                            color: chatProvider.messages.isEmpty
                                ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)
                                : Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Submit button
                        Container(
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
                      ],
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
    final chatProvider = context.watch<ChatProvider>();
    
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
              hintText: 'Let\'s talk about SEO for your website...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Download CSV button
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: chatProvider.messages.isEmpty
                            ? Theme.of(context).colorScheme.surfaceVariant
                            : Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        onPressed: chatProvider.messages.isEmpty ? null : _downloadConversationAsCSV,
                        icon: const Icon(Icons.download),
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        color: chatProvider.messages.isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)
                            : Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Submit button
                    Container(
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
                  ],
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

