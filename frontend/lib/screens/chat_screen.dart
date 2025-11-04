import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/project_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/conversation_list.dart';
import '../widgets/theme_switcher.dart';
import '../widgets/cli_spinner.dart';
import '../widgets/favicon_widget.dart';
import 'dart:html' as html;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum ViewState { chat, conversations, projects }
enum ProjectViewState { list, detail }
enum ProjectTab { overview, pinboard, keywords, backlinks }

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasShownWelcomeModal = false;
  bool _hasLoadedProjects = false;
  String _selectedMode = 'ask'; // 'ask' or 'agent'
  bool _shouldCancelRequest = false;
  ViewState _currentView = ViewState.chat;
  ProjectViewState _projectViewState = ProjectViewState.list;
  ProjectTab _selectedProjectTab = ProjectTab.keywords;

  @override
  void initState() {
    super.initState();
    // Show welcome modal and load projects after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Welcome modal disabled
      // if (!_hasShownWelcomeModal) {
      //   _showWelcomeModal();
      //   _hasShownWelcomeModal = true;
      // }
      
      // Load projects once
      if (!_hasLoadedProjects) {
        final authProvider = context.read<AuthProvider>();
        final projectProvider = context.read<ProjectProvider>();
        projectProvider.loadAllProjects(authProvider.apiService);
        _hasLoadedProjects = true;
      }

      // Listen for chat updates and auto-scroll
      final chatProvider = context.read<ChatProvider>();
      chatProvider.addListener(_scrollToBottom);
    });
  }

  @override
  void dispose() {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.removeListener(_scrollToBottom);
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
    // Scroll to bottom after a short delay to allow content to render
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

  void _stopGeneration() {
    final chatProvider = context.read<ChatProvider>();
    setState(() {
      _shouldCancelRequest = true;
    });
    chatProvider.setLoading(false);
  }

  Future<void> _sendMessage() async {
    final chatProvider = context.read<ChatProvider>();
    
    // If currently loading, stop the generation
    if (chatProvider.isLoading) {
      _stopGeneration();
      return;
    }
    
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final authProvider = context.read<AuthProvider>();

    // Add user message immediately
    chatProvider.addMessage(Message(
      id: DateTime.now().toString(),
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
    ));
    
    _messageController.clear();
    _scrollToBottom();

    setState(() {
      _shouldCancelRequest = false;
    });
    
    // Start with initial loading status
    chatProvider.setLoading(true, status: 'Thinking...');

    try {
      // Use streaming endpoint to get real-time status updates
      await for (final event in authProvider.apiService.sendMessageStream(
        message,
        chatProvider.currentConversationId,
        mode: _selectedMode,
      )) {
        // Check if request was cancelled
        if (_shouldCancelRequest) {
          break;
        }

        final eventType = event['event'] as String;
        final data = event['data'] as Map<String, dynamic>;

        if (eventType == 'status') {
          // Update loading status based on backend events
          chatProvider.setLoading(true, status: data['message'] as String);
        } else if (eventType == 'message') {
          // Final response received
          chatProvider.setCurrentConversation(data['conversation_id'] as String);
          chatProvider.addMessage(Message(
            id: DateTime.now().toString(),
            role: 'assistant',
            content: data['message'] as String,
            createdAt: DateTime.now(),
          ));
          _scrollToBottom();
        } else if (eventType == 'error') {
          // Error occurred
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${data['message']}')),
            );
          }
          break;
        } else if (eventType == 'done') {
          // Stream completed
          break;
        }
      }
    } catch (e) {
      if (mounted && !_shouldCancelRequest) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (!_shouldCancelRequest) {
        chatProvider.setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
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
                // Logo - clickable to start new conversation
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      chatProvider.startNewConversation();
                      MessageBubble.clearAnimationCache();
                      setState(() {
                        _currentView = ViewState.chat;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        'K',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
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
                      _currentView = ViewState.chat;
                    });
                  },
                  icon: const Icon(Icons.add),
                  iconSize: 28,
                  tooltip: 'New conversation',
                ),
                const SizedBox(height: 12),
                // Conversations button
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentView = ViewState.conversations;
                    });
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  style: IconButton.styleFrom(
                    backgroundColor: _currentView == ViewState.conversations
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  tooltip: 'Conversations',
                ),
                const SizedBox(height: 12),
                // Projects button
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentView = ViewState.projects;
                      _projectViewState = ProjectViewState.list; // Reset to list view
                    });
                  },
                  icon: const Icon(Icons.track_changes),
                  style: IconButton.styleFrom(
                    backgroundColor: _currentView == ViewState.projects
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  tooltip: 'My SEO Projects',
                ),
                const Spacer(),
                // Theme switcher
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ThemeSwitcher(),
                ),
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
          
          // Main content area - switches between views
          Expanded(
            child: _buildMainContent(),
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
                  // Title with colored "Keywords"
                  RichText(
                    text: TextSpan(
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      ),
                      children: [
                        const TextSpan(text: 'Welcome to '),
                        // Colored "Keywords"
                        TextSpan(
                          text: 'Keywords',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: Theme.of(context).textTheme.headlineMedium?.fontSize,
                          ),
                        ),
                        const TextSpan(text: '.chat'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Powerful SEO toolkit at your command',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 64),
              
              // Centered input with mode selector
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _selectedMode == 'agent'
                            ? 'Share your website and I\'ll guide you through SEO strategy...'
                            : 'Ask me to analyze a website, research keywords, check rankings...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                    
                    // Bottom toolbar with mode selector and buttons
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Mode selector dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedMode,
                              underline: const SizedBox(),
                              isDense: true,
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                size: 14,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                              ),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'ask',
                                  child: Tooltip(
                                    message: 'Ask Mode: You control the workflow - give direct commands',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 12,
                                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('Ask'),
                                      ],
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'agent',
                                  child: Tooltip(
                                    message: 'Agent Mode: Strategic SEO guidance with proactive recommendations',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 12,
                                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('Agent'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedMode = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const Spacer(),
                          // Pin conversation button
                          chatProvider.messages.isEmpty
                              ? Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.bookmark_border,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                                  ),
                                )
                              : Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: PopupMenuButton<String>(
                                    tooltip: 'Pin this conversation',
                                    icon: Icon(
                                      Icons.bookmark_border,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                    padding: EdgeInsets.zero,
                                    iconSize: 16,
                                    onSelected: (value) async {
                                      if (value == 'new_project') {
                                        await _createProjectAndPinConversation();
                                      } else {
                                        await _pinConversationToProject(value);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) {
                                      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
                                      final items = <PopupMenuEntry<String>>[];
                                      
                                      if (projectProvider.allProjects.isEmpty) {
                                        items.add(
                                          const PopupMenuItem<String>(
                                            value: 'new_project',
                                            height: 32,
                                            child: Row(
                                              children: [
                                                Icon(Icons.add, size: 16),
                                                SizedBox(width: 8),
                                                Text('Create new project', style: TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                          ),
                                        );
                                      } else {
                                        items.addAll(projectProvider.allProjects.map((project) {
                                          return PopupMenuItem<String>(
                                            value: project.id,
                                            height: 32,
                                            child: Text(
                                              project.name,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          );
                                        }));
                                        
                                        // Add separator and "Create new project" option
                                        items.add(
                                          const PopupMenuItem<String>(
                                            value: 'separator',
                                            enabled: false,
                                            height: 8,
                                            child: Divider(),
                                          ),
                                        );
                                        items.add(
                                          const PopupMenuItem<String>(
                                            value: 'new_project',
                                            height: 32,
                                            child: Row(
                                              children: [
                                                Icon(Icons.add, size: 16),
                                                SizedBox(width: 8),
                                                Text('Create new project', style: TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      return items;
                                    },
                                  ),
                                ),
                          const SizedBox(width: 8),
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
                          // Submit/Stop button
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: chatProvider.isLoading
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IconButton(
                              onPressed: _sendMessage,
                              icon: Icon(
                                chatProvider.isLoading ? Icons.stop : Icons.arrow_upward,
                              ),
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Suggestion buttons
              const SizedBox(height: 12),
              _buildSuggestionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSuggestionButton(
          icon: Icons.search,
          label: 'Keywords',
          message: 'I want to research keywords',
        ),
        const SizedBox(width: 8),
        _buildSuggestionButton(
          icon: Icons.bar_chart,
          label: 'SERP',
          message: 'Analyze SERP results for a keyword',
        ),
        const SizedBox(width: 8),
        _buildSuggestionButton(
          icon: Icons.trending_up,
          label: 'Rankings',
          message: 'Check my rankings',
        ),
        const SizedBox(width: 8),
        _buildSuggestionButton(
          icon: Icons.language,
          label: 'Website',
          message: 'Analyze my website',
        ),
        const SizedBox(width: 8),
        _buildSuggestionButton(
          icon: Icons.link,
          label: 'Backlinks',
          message: 'Show me backlinks for my website',
        ),
        const SizedBox(width: 8),
        _buildSuggestionButton(
          icon: Icons.people_outline,
          label: 'Competitors',
          message: 'Analyze competitor keywords',
        ),
      ],
    );
  }
  
  Widget _buildSuggestionButton({
    required IconData icon,
    required String label,
    required String message,
  }) {
    return Tooltip(
      message: message,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _messageController.text = message;
          _sendMessage();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final chatProvider = context.watch<ChatProvider>();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text input area
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _selectedMode == 'agent'
                        ? 'Share your website and I\'ll guide you through SEO strategy...'
                        : 'Ask me to analyze a website, research keywords, check rankings...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
                
                // Bottom toolbar with mode selector and buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Mode selector dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedMode,
                          underline: const SizedBox(),
                          isDense: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            size: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'ask',
                              child: Tooltip(
                                message: 'Ask Mode: You control the workflow - give direct commands',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 12,
                                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Ask'),
                                  ],
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'agent',
                              child: Tooltip(
                                message: 'Agent Mode: Strategic SEO guidance with proactive recommendations',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 12,
                                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Agent'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMode = value;
                              });
                            }
                          },
                        ),
                      ),
                      const Spacer(),
                      // Pin conversation button
                      chatProvider.messages.isEmpty
                          ? Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.bookmark_border,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                              ),
                            )
                          : Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: PopupMenuButton<String>(
                                tooltip: 'Pin this conversation',
                                icon: Icon(
                                  Icons.bookmark_border,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                onSelected: (value) async {
                                  if (value == 'new_project') {
                                    await _createProjectAndPinConversation();
                                  } else {
                                    await _pinConversationToProject(value);
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
                                  final items = <PopupMenuEntry<String>>[];
                                  
                                  if (projectProvider.allProjects.isEmpty) {
                                    items.add(
                                      const PopupMenuItem<String>(
                                        value: 'new_project',
                                        height: 32,
                                        child: Row(
                                          children: [
                                            Icon(Icons.add, size: 16),
                                            SizedBox(width: 8),
                                            Text('Create new project', style: TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    items.addAll(projectProvider.allProjects.map((project) {
                                      return PopupMenuItem<String>(
                                        value: project.id,
                                        height: 32,
                                        child: Text(
                                          project.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }));
                                    
                                    // Add separator and "Create new project" option
                                    items.add(
                                      const PopupMenuItem<String>(
                                        value: 'separator',
                                        enabled: false,
                                        height: 8,
                                        child: Divider(),
                                      ),
                                    );
                                    items.add(
                                      const PopupMenuItem<String>(
                                        value: 'new_project',
                                        height: 32,
                                        child: Row(
                                          children: [
                                            Icon(Icons.add, size: 16),
                                            SizedBox(width: 8),
                                            Text('Create new project', style: TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  return items;
                                },
                              ),
                            ),
                      const SizedBox(width: 8),
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
                      // Submit/Stop button
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: chatProvider.isLoading
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: Icon(
                            chatProvider.isLoading ? Icons.stop : Icons.arrow_upward,
                          ),
                          iconSize: 16,
                          padding: EdgeInsets.zero,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final projectProvider = context.watch<ProjectProvider>();
    final currentProjectId = projectProvider.selectedProject?.id;


    return Column(
        children: [
          // Messages and Input
          Expanded(
            child: chatProvider.messages.isEmpty && !chatProvider.isLoading
                ? _buildEmptyStateWithInput()
                : Column(
                    children: [
                      // Messages area
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show typing indicator as last item when loading
                            if (index == chatProvider.messages.length && chatProvider.isLoading) {
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 900),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CliSpinner(
                                                size: 13,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                chatProvider.loadingStatus,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 900),
                                child: MessageBubble(
                                  message: chatProvider.messages[index],
                                  projectId: currentProjectId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Input area (bottom) - show when there are messages or loading
                      if (chatProvider.messages.isNotEmpty || chatProvider.isLoading)
                        _buildInputArea(),
                    ],
                  ),
              ),
            ],
          );
  }

  Widget _buildConversationsView() {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your conversations',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your chat history',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            
            // Conversations list
            Expanded(
              child: ConversationList(
                onConversationSelected: (conversationId) async {
                  chatProvider.setLoading(true);
                  
                  try {
                    final conversationData = await authProvider.apiService.getConversation(conversationId);
                    
                    // Load messages
                    final messages = (conversationData['messages'] as List).map((m) => Message(
                      id: m['id'],
                      role: m['role'],
                      content: m['content'],
                      createdAt: DateTime.parse(m['created_at']),
                      messageMetadata: m['message_metadata'] as Map<String, dynamic>?,
                    )).toList();
                    
                    chatProvider.setCurrentConversation(conversationId);
                    chatProvider.setMessages(messages);
                    
                    // Switch back to chat view
                    setState(() {
                      _currentView = ViewState.chat;
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
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsView() {
    switch (_projectViewState) {
      case ProjectViewState.list:
        return _buildProjectsListView();
      case ProjectViewState.detail:
        return _buildProjectDetailView();
    }
  }

  Widget _buildProjectsListView() {
    final projectProvider = context.watch<ProjectProvider>();
    final authProvider = context.watch<AuthProvider>();
    final projects = projectProvider.allProjects;
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEO Projects',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SEO projects and keyword tracking',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Create project button
                  ElevatedButton.icon(
                    onPressed: () => _showCreateProjectDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            // Projects list
            Expanded(
              child: projectProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : projects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.track_changes,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No SEO Projects Yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first SEO project',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: projects.length,
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () async {
                                  await projectProvider.selectProject(authProvider.apiService, project);
                                  setState(() {
                                    _projectViewState = ProjectViewState.detail;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      // Icon
                                      FaviconWidget(
                                        url: project.targetUrl,
                                        size: 48,
                                        apiService: authProvider.apiService,
                                      ),
                                      const SizedBox(width: 16),
                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              project.name,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              project.targetUrl,
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.grey[400],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Arrow
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProjectDetailView() {
    final projectProvider = context.watch<ProjectProvider>();
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final project = projectProvider.selectedProject;
    final keywords = projectProvider.trackedKeywords;

    if (project == null) {
      // Shouldn't happen, but fallback to list view
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _projectViewState = ProjectViewState.list;
        });
      });
      return const Center(child: CircularProgressIndicator());
    }
    
    // Load conversations if not already loaded
    if (chatProvider.conversations.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final conversations = await authProvider.apiService.getConversations();
          final conversationList = conversations.map((c) => Conversation(
            id: c['id'],
            title: c['title'],
            createdAt: DateTime.parse(c['created_at']),
            messageCount: c['message_count'],
            projectNames: (c['project_names'] as List<dynamic>?)?.cast<String>() ?? [],
          )).toList();
          conversationList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          chatProvider.setConversations(conversationList);
        } catch (e) {
          // Silently handle error - conversations are optional
        }
      });
    }

    return DefaultTabController(
      length: 3,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _projectViewState = ProjectViewState.list;
                      });
                    },
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to SEO projects'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Project info
                  Row(
                    children: [
                      FaviconWidget(
                        url: project.targetUrl,
                        size: 56,
                        iconSize: 28,
                        apiService: authProvider.apiService,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.targetUrl,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Chat button - prominent call to action
                      FilledButton.icon(
                        onPressed: () {
                          // Start a new conversation with project context
                          final chatProvider = context.read<ChatProvider>();
                          final project = projectProvider.selectedProject!;
                          chatProvider.startNewConversation();
                          MessageBubble.clearAnimationCache();
                          setState(() {
                            _currentView = ViewState.chat;
                          });
                          // Send a simple project-aware message after the UI updates
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _messageController.text = "Let's work on my ${project.name} project (${project.targetUrl}).";
                            _sendMessage();
                          });
                        },
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        label: const Text('Work on SEO Strategy'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Refresh buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: projectProvider.isLoading
                                ? null
                                : () async {
                                    try {
                                      await projectProvider.refreshRankings(authProvider.apiService);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Keywords updated!')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.search),
                            tooltip: 'Refresh Keywords',
                            iconSize: 20,
                          ),
                          IconButton(
                            onPressed: projectProvider.isLoading
                                ? null
                                : () async {
                                    try {
                                      await projectProvider.refreshBacklinks(authProvider.apiService, project.id);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Backlinks refreshed!')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.link),
                            tooltip: 'Refresh Backlinks',
                            iconSize: 20,
                          ),
                        ],
                      ),
                      // Delete button
                      IconButton(
                        onPressed: projectProvider.isLoading
                            ? null
                            : () async {
                                // Show confirmation dialog
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Project'),
                                    content: Text(
                                      'Are you sure you want to delete "${project.name}"?\n\nThis will permanently delete:\n• All tracked keywords\n• Ranking history\n\nThis action cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirmed == true) {
                                  try {
                                    await authProvider.apiService.deleteProject(project.id);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Project deleted successfully')),
                                      );
                                      // Go back to project list
                                      setState(() {
                                        _projectViewState = ProjectViewState.list;
                                      });
                                      // Reload projects
                                      projectProvider.loadAllProjects(authProvider.apiService);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error deleting project: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete Project',
                        color: Colors.red[400],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tabs with counts
                  TabBar(
                    onTap: (index) {
                      setState(() {
                        _selectedProjectTab = ProjectTab.values[index];
                      });
                    },
                    tabs: [
                      const Tab(text: 'Overview'),
                      const Tab(text: 'Pinboard'),
                      Tab(text: 'Keywords (${keywords.length})'),
                      Tab(text: 'Backlinks (${projectProvider.backlinksData?['total_backlinks'] ?? 0})'),
                    ],
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                children: [
                  _buildOverviewTab(project, projectProvider),
                  _buildPinboardTab(project),
                  _buildKeywordsTab(projectProvider, keywords),
                  _buildBacklinksTab(project),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildOverviewTab(Project project, ProjectProvider projectProvider) {
    final backlinksData = projectProvider.backlinksData;
    
    // Extract metrics
    final domainAuthority = backlinksData?['domain_authority'] ?? 0;
    final totalBacklinks = backlinksData?['total_backlinks'] ?? 0;
    final referringDomains = backlinksData?['referring_domains'] ?? 0;
    final overtime = backlinksData?['overtime'] as List? ?? [];
    final newAndLost = backlinksData?['new_and_lost'] as List? ?? [];
    final isCached = backlinksData?['is_cached'] == true;
    final cacheNote = backlinksData?['cache_note'] as String?;
    final hasError = backlinksData?['error'] != null;
    final errorMessage = backlinksData?['error'] as String?;
    
    return projectProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show cache/error notice
                if (isCached || hasError) ...[
                  Card(
                    color: isCached ? Colors.blue[50] : Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(
                            isCached ? Icons.cached : Icons.warning_amber,
                            size: 20,
                            color: isCached ? Colors.blue[700] : Colors.orange[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cacheNote ?? errorMessage ?? 'Using cached data',
                              style: TextStyle(
                                fontSize: 12,
                                color: isCached ? Colors.blue[900] : Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Key Metrics Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Domain Authority',
                        domainAuthority.toString(),
                        Icons.shield_outlined,
                        _getDomainAuthorityColor(domainAuthority),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Total Backlinks',
                        _formatNumber(totalBacklinks),
                        Icons.link,
                        Colors.blue[400]!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Referring Domains',
                        _formatNumber(referringDomains),
                        Icons.language,
                        Colors.purple[400]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'New/Lost (7d)',
                        _getNewLostSummary(newAndLost),
                        Icons.trending_up,
                        Colors.green[400]!,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Historical Trend Chart
                if (overtime.isNotEmpty) ...[
                  Text(
                    'Domain Authority Trend',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            child: _buildHistoricalChart(overtime),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Backlinks Growth Chart
                if (overtime.isNotEmpty) ...[
                  Text(
                    'Backlinks Growth',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            child: _buildBacklinksChart(overtime),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Recent Activity
                if (newAndLost.isNotEmpty) ...[
                  Text(
                    'Recent Activity (Last 30 Days)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildActivityList(newAndLost.take(10).toList()),
                    ),
                  ),
                ],
                
                // If no data
                if (overtime.isEmpty && newAndLost.isEmpty) ...[
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Data Yet',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Analyze backlinks to see metrics',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
  }
  
  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getDomainAuthorityColor(int da) {
    if (da >= 70) return Colors.green[600]!;
    if (da >= 50) return Colors.blue[600]!;
    if (da >= 30) return Colors.orange[600]!;
    return Colors.red[600]!;
  }
  
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
  
  String _getNewLostSummary(List newAndLost) {
    if (newAndLost.isEmpty) return '0/0';
    
    int totalNew = 0;
    int totalLost = 0;
    
    // Last 7 days
    final recentData = newAndLost.take(7).toList();
    for (var day in recentData) {
      totalNew += (day['new_backlinks'] ?? 0) as int;
      totalLost += (day['lost_backlinks'] ?? 0) as int;
    }
    
    final newStr = totalNew > 0 ? '+${_formatNumber(totalNew)}' : '0';
    final lostStr = totalLost > 0 ? '-${_formatNumber(totalLost)}' : '0';
    
    return '$newStr / $lostStr';
  }
  
  Widget _buildHistoricalChart(List overtime) {
    // Simple line chart visualization
    final data = overtime.take(30).toList().reversed.toList();
    
    return CustomPaint(
      painter: LineChartPainter(
        data: data,
        color: _getDomainAuthorityColor(data.last['da'] ?? 0),
        dataKey: 'da',
        labelFormatter: (value) => value.toInt().toString(),
      ),
      child: Container(),
    );
  }
  
  Widget _buildBacklinksChart(List overtime) {
    // Simple line chart for backlinks
    final data = overtime.take(30).toList().reversed.toList();
    
    return CustomPaint(
      painter: LineChartPainter(
        data: data,
        color: Colors.blue[400]!,
        dataKey: 'backlinks',
        labelFormatter: (value) => _formatNumber(value.toInt()),
      ),
      child: Container(),
    );
  }
  
  Widget _buildActivityList(List newAndLost) {
    return Column(
      children: newAndLost.map((day) {
        final date = day['date'] ?? 'Unknown';
        final newLinks = day['new_backlinks'] ?? 0;
        final lostLinks = day['lost_backlinks'] ?? 0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      newLinks.toString(),
                      style: TextStyle(
                        color: Colors.green[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.remove, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 4),
                    Text(
                      lostLinks.toString(),
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPinboardTab(Project project) {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    
    // Filter conversations related to this project
    final relatedConversations = chatProvider.conversations
        .where((conv) => conv.projectNames.contains(project.name))
        .toList();
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: authProvider.apiService.getPinnedItems(projectId: project.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final pinnedItems = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pinned Items Section (moved to top)
            Row(
              children: [
                Icon(Icons.push_pin, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pinned Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (pinnedItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.push_pin,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No pinned items yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pin important responses from chat',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...pinnedItems.map((item) => _buildPinListItem(item)).toList(),
            
            // Related Conversations Section (moved to bottom)
            if (relatedConversations.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Related Conversations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...relatedConversations.map((conversation) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.forum,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatDate(conversation.createdAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      chatProvider.setLoading(true);
                      
                      try {
                        final conversationData = await authProvider.apiService.getConversation(conversation.id);
                        
                        final messages = (conversationData['messages'] as List).map((m) => Message(
                          id: m['id'],
                          role: m['role'],
                          content: m['content'],
                          createdAt: DateTime.parse(m['created_at']),
                          messageMetadata: m['message_metadata'] as Map<String, dynamic>?,
                        )).toList();
                        
                        chatProvider.setCurrentConversation(conversation.id);
                        chatProvider.setMessages(messages);
                        
                        setState(() {
                          _currentView = ViewState.chat;
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
                );
              }).toList(),
            ],
          ],
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
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

  Widget _buildPinListItem(Map<String, dynamic> item) {
    final isConversation = item['content_type'] == 'conversation';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          isConversation ? Icons.bookmark : Icons.push_pin,
          color: isConversation ? Colors.blue : null,
        ),
        title: Text(
          item['title'] ?? 'Pinned Item',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pinned ${DateTime.parse(item['created_at']).toLocal().toString().split('.')[0]}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            // Content type badge
            if (isConversation) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Full Conversation',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Content preview
            Text(
              _getContentPreview(item),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            try {
              await Provider.of<AuthProvider>(context, listen: false)
                  .apiService
                  .unpinItem(item['id']);
              setState(() {}); // Refresh the tab
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item unpinned')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          tooltip: 'Unpin this item',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display content based on type
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MarkdownBody(
                    data: item['content'],
                    styleSheet: MarkdownStyleSheet(
                      p: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                if (item['source_message_id'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'From conversation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getContentPreview(Map<String, dynamic> item) {
    final content = item['content'] as String? ?? '';
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
    if (preview.length > 100) {
      preview = '${preview.substring(0, 97)}...';
    }

    return preview.isEmpty ? 'No content' : preview;
  }

  Future<void> _createProjectAndPinConversation() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'e.g., My AI Chatbot',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Website URL',
                hintText: 'e.g., https://example.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create & Pin'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      final url = urlController.text.trim();

      if (name.isEmpty || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both project name and URL'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final projectProvider = Provider.of<ProjectProvider>(context, listen: false);

        // Create the project
        final projectResponse = await authProvider.apiService.createProject(url, name);
        final newProjectId = projectResponse['id'];

        // Refresh projects list
        await projectProvider.loadAllProjects(authProvider.apiService);

        // Pin the conversation to the new project
        await _pinConversationToProject(newProjectId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating project: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pinConversationToProject(String projectId) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);

    final conversationId = chatProvider.currentConversationId;
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No conversation to pin')),
      );
      return;
    }

    try {
      await authProvider.apiService.pinConversation(
        conversationId: conversationId,
        projectId: projectId,
      );

      if (mounted) {
        final project = projectProvider.allProjects.firstWhere(
          (p) => p.id == projectId,
          orElse: () => throw Exception('Project not found'),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Conversation pinned to "${project.name}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pinning conversation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Selected keywords state
  final Set<String> _selectedKeywordIds = {};

  Widget _buildKeywordsTab(ProjectProvider projectProvider, List<TrackedKeyword> keywords) {
    return projectProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : keywords.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Keywords Yet',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add keywords from the chat to start tracking',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Bulk actions bar (shown when keywords are selected)
                  if (_selectedKeywordIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Row(
                        children: [
                          Text(
                            '${_selectedKeywordIds.length} selected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Stop Tracking Keywords'),
                                  content: Text('Stop tracking ${_selectedKeywordIds.length} keyword(s)?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Stop Tracking'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true && mounted) {
                                // TODO: Implement stop tracking API call
                                setState(() {
                                  _selectedKeywordIds.clear();
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Keywords stopped tracking')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.pause_circle_outline),
                            label: const Text('Stop Tracking'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Keywords'),
                                  content: Text('Permanently remove ${_selectedKeywordIds.length} keyword(s)?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                      ),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true && mounted) {
                                // TODO: Implement remove keywords API call
                                setState(() {
                                  _selectedKeywordIds.clear();
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Keywords removed')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Keywords list
                  Expanded(
                    child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: keywords.length + 1, // +1 for the Add Keyword button
                          itemBuilder: (context, index) {
                            // Add Keyword button at the end
                            if (index == keywords.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showAddKeywordDialog(context, projectProvider, Provider.of<AuthProvider>(context, listen: false)),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Keyword'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final keyword = keywords[index];
                            final isSelected = _selectedKeywordIds.contains(keyword.id);
                            
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                    : null,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedKeywordIds.remove(keyword.id);
                                      } else {
                                        _selectedKeywordIds.add(keyword.id);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        // Checkbox
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: Checkbox(
                                            value: isSelected,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedKeywordIds.add(keyword.id);
                                                } else {
                                                  _selectedKeywordIds.remove(keyword.id);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Keyword info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                keyword.keyword,
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.search,
                                                    size: 14,
                                                    color: Colors.grey[500],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${keyword.searchVolume ?? '--'} searches/mo',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Icon(
                                                    Icons.trending_up,
                                                    size: 14,
                                                    color: Colors.grey[500],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    keyword.competition?.toUpperCase() ?? 'UNKNOWN',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                    const SizedBox(width: 16),
                                    // Sparkline chart
                                    FutureBuilder<Map<String, dynamic>>(
                                      future: Provider.of<AuthProvider>(context, listen: false).apiService.getKeywordHistory(keyword.id),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data?['history'] != null) {
                                          final history = snapshot.data!['history'] as List;
                                          if (history.length >= 2) {
                                            // Extract positions for sparkline
                                            final positions = history
                                                .map((e) => (e as Map<String, dynamic>)['position'] as int?)
                                                .where((p) => p != null)
                                                .map((p) => p!.toDouble())
                                                .toList();

                                            if (positions.length >= 2) {
                                              final firstPos = positions.first;
                                              final lastPos = positions.last;
                                              final change = firstPos - lastPos;
                                              final isImproving = change > 0;

                                              return SizedBox(
                                                width: 80,
                                                height: 40,
                                                child: CustomPaint(
                                                  painter: SparklinePainter(
                                                    positions,
                                                    isImproving ? Colors.green : Colors.red,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                        return const SizedBox(width: 80, height: 40);
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    // Position badge
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: _getPositionColor(keyword.currentPosition).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          keyword.currentPosition?.toString() ?? '101+',
                                          style: TextStyle(
                                            color: _getPositionColor(keyword.currentPosition),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
  }

  Widget _buildBacklinksTab(Project project) {
    final projectProvider = context.watch<ProjectProvider>();
    final authProvider = context.watch<AuthProvider>();

    // Load backlinks data if not loaded yet
    if (projectProvider.backlinksData == null && !projectProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        projectProvider.loadBacklinksData(authProvider.apiService, project.id);
      });
    }

    if (projectProvider.isLoading && projectProvider.backlinksData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (projectProvider.backlinksData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => projectProvider.loadBacklinksData(authProvider.apiService, project.id),
              icon: const Icon(Icons.refresh),
              tooltip: 'Load backlinks data',
            ),
            const SizedBox(height: 16),
            const Text('Click to load backlinks data'),
          ],
        ),
      );
    }

    final data = projectProvider.backlinksData;
    final backlinks = (data?['backlinks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalBacklinks = data?['total_backlinks'] ?? 0;
    final referringDomains = data?['referring_domains'] ?? 0;
    final domainAuthority = data?['domain_authority'] ?? 0;
    final analyzedAt = data?['analyzed_at'] as String?;

    if (backlinks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No Backlinks Analyzed Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click the button below to analyze backlinks for this project',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await projectProvider.refreshBacklinks(authProvider.apiService, project.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backlinks analyzed!')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Analyze Backlinks'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary stats
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusChip('Total Backlinks', totalBacklinks, Theme.of(context).colorScheme.primary),
                  _buildStatusChip('Referring Domains', referringDomains, Theme.of(context).colorScheme.secondary),
                  _buildStatusChip('Domain Authority', domainAuthority, Theme.of(context).colorScheme.tertiary),
                ],
              ),
              if (analyzedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last analyzed: ${_formatAnalyzedDate(analyzedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        // List of backlinks
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: backlinks.length,
            itemBuilder: (context, index) {
              final backlink = backlinks[index];
              final sourceUrl = backlink['url_from'] as String?;
              final targetUrl = backlink['url_to'] as String?;
              final anchorText = backlink['anchor'] as String?;
              final inlinkRank = backlink['inlink_rank'] as num?;
              final isNofollow = backlink['nofollow'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isNofollow 
                        ? Theme.of(context).colorScheme.surfaceVariant
                        : Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isNofollow ? Icons.link_off : Icons.link,
                      color: isNofollow
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    sourceUrl ?? 'Unknown source',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (anchorText != null && anchorText.isNotEmpty)
                        Text(
                          'Anchor: "$anchorText"',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (inlinkRank != null)
                        Text(
                          'Link Quality: ${inlinkRank.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: isNofollow
                      ? const Chip(
                          label: Text('NOFOLLOW', style: TextStyle(fontSize: 10)),
                          padding: EdgeInsets.symmetric(horizontal: 4),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'submitted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'indexed':
        return Colors.blue;
      case 'approved':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case 'submitted':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'pending':
        icon = Icons.pending;
        color = Colors.orange;
        break;
      case 'indexed':
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.circle_outlined;
        color = Colors.grey;
    }
    
    return Icon(icon, color: color);
  }

  Color _getPositionColor(int? position) {
    if (position == null) return Colors.grey;
    if (position <= 3) return Colors.green;
    if (position <= 10) return Colors.orange;
    return Colors.red;
  }
  
  void _showCreateProjectDialog() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Target Website URL',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (urlController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a URL')),
                );
                return;
              }
              
              try {
                final projectProvider = context.read<ProjectProvider>();
                final authProvider = context.read<AuthProvider>();
                
                await projectProvider.createProject(
                  authProvider.apiService,
                  urlController.text,
                  nameController.text.isEmpty ? null : nameController.text,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project created successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddKeywordDialog(BuildContext context, ProjectProvider projectProvider, AuthProvider authProvider) {
    final keywordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Keyword'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: 'Keyword',
                  hintText: 'Enter keyword to track',
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Search volume and competition will be automatically fetched and tracked.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (keywordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a keyword')),
                  );
                  return;
                }

                try {
                  await projectProvider.addKeyword(
                    authProvider.apiService,
                    keywordController.text.trim(),
                    null, // Let backend fetch search volume
                    null, // Let backend determine competition
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Keyword added successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding keyword: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }


  String _formatAnalyzedDate(String isoDate) {
    try {
      final analyzed = DateTime.parse(isoDate);
      final now = DateTime.now();
      final difference = now.difference(analyzed);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatLastUpdated(List<TrackedKeyword> keywords) {
    if (keywords.isEmpty) {
      return 'Never';
    }

    // Find the most recent keyword creation/update time
    DateTime mostRecent = keywords
        .map((k) => k.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final now = DateTime.now();
    final difference = now.difference(mostRecent);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Sparkline painter for keyword ranking history
class SparklinePainter extends CustomPainter {
  final List<double> positions;
  final Color lineColor;

  SparklinePainter(this.positions, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Find min and max for scaling (remember lower position is better)
    final minPos = positions.reduce((a, b) => a < b ? a : b);
    final maxPos = positions.reduce((a, b) => a > b ? a : b);
    final range = maxPos - minPos;

    if (range == 0) {
      // All positions are the same, draw a flat line
      final y = size.height / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
      return;
    }

    final path = Path();
    for (int i = 0; i < positions.length; i++) {
      final x = (i / (positions.length - 1)) * size.width;
      // Invert Y because lower ranking position is better (should be higher on graph)
      final normalizedPos = (maxPos - positions[i]) / range;
      final y = normalizedPos * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) {
    return oldDelegate.positions != positions || oldDelegate.lineColor != lineColor;
  }
}

// Line chart painter for overview tab
class LineChartPainter extends CustomPainter {
  final List data;
  final Color color;
  final String dataKey;
  final String Function(double) labelFormatter;

  LineChartPainter({
    required this.data,
    required this.color,
    required this.dataKey,
    required this.labelFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Find min and max values
    final values = data.map((d) => (d[dataKey] ?? 0).toDouble()).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;

    // Handle flat line case
    final effectiveRange = range == 0 ? 1.0 : range;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw the line chart
    final path = Path();
    final fillPath = Path();
    
    fillPath.moveTo(0, size.height);
    
    for (int i = 0; i < data.length; i++) {
      final value = (data[i][dataKey] ?? 0).toDouble();
      final x = size.width * i / (data.length - 1);
      final y = size.height - ((value - minValue) / effectiveRange * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final value = (data[i][dataKey] ?? 0).toDouble();
      final x = size.width * i / (data.length - 1);
      final y = size.height - ((value - minValue) / effectiveRange * size.height);
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}

