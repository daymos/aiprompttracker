import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/project_provider.dart';
import '../services/api_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/conversation_list.dart';
import '../widgets/theme_switcher.dart';
import '../widgets/cli_spinner.dart';
import '../widgets/favicon_widget.dart';
import '../widgets/grid_pattern_background.dart';
import '../widgets/data_panel.dart';
import 'dart:html' as html;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum ViewState { chat, conversations, projects }
enum ProjectViewState { list, detail }
enum ProjectTab { overview, pinboard, keywords, backlinks, chat }

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
  Timer? _keywordPollingTimer;

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
    _keywordPollingTimer?.cancel();
    super.dispose();
  }

  void _startKeywordPolling() {
    // Cancel any existing timer
    _keywordPollingTimer?.cancel();
    
    // Poll every 10 seconds for new keywords
    _keywordPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final projectProvider = context.read<ProjectProvider>();
      final authProvider = context.read<AuthProvider>();
      
      if (projectProvider.activeProject != null) {
        await projectProvider.loadTrackedKeywords(
          authProvider.apiService,
          projectProvider.activeProject!.id,
        );
        
        // Stop polling if keywords are found
        if (projectProvider.trackedKeywords.isNotEmpty) {
          timer.cancel();
          _keywordPollingTimer = null;
        }
      } else {
        // No active project, stop polling
        timer.cancel();
        _keywordPollingTimer = null;
      }
    });
  }

  void _stopKeywordPolling() {
    _keywordPollingTimer?.cancel();
    _keywordPollingTimer = null;
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
            messageMetadata: data['metadata'] as Map<String, dynamic>?,
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
      body: GridPatternBackground(
        child: Row(
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
                      child: SvgPicture.network(
                        '/logo-icon.svg',
                        width: 40,
                        height: 40,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                        placeholderBuilder: (context) => Text(
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

    final chatContent = Column(
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
    
    // Wrap in Row to support side panel
    return Row(
      children: [
        Expanded(
          child: chatContent,
        ),
        if (chatProvider.dataPanelOpen)
          DataPanel(
            data: chatProvider.dataPanelData,
            columns: _buildDataPanelColumns(chatProvider.dataPanelTitle),
            title: chatProvider.dataPanelTitle,
            onClose: () => chatProvider.closeDataPanel(),
            csvFilename: '${chatProvider.dataPanelTitle.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv',
            projects: projectProvider.allProjects.map((p) => {
              'id': p.id,
              'name': p.name,
            }).toList(),
            onAddToProject: (projectId, selectedKeywords) async {
              final authProvider = context.read<AuthProvider>();
              try {
                // Add each keyword to the project
                for (var keyword in selectedKeywords) {
                  await authProvider.apiService.addKeywordToProject(
                    projectId,
                    keyword['keyword'] as String,
                    keyword['search_volume'] as int?,
                    keyword['competition'] as String?,
                  );
                }
                
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully added ${selectedKeywords.length} keyword(s) to project'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Refresh the project data if it's the active one
                if (projectProvider.selectedProject?.id == projectId) {
                  await projectProvider.loadTrackedKeywords(authProvider.apiService, projectId);
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding keywords: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
      ],
    );
  }

  List<DataColumnConfig> _buildDataPanelColumns(String title) {
    // Detect data type from title or data structure
    if (title.toLowerCase().contains('ranking')) {
      return _buildRankingColumns();
    }
    // Default to keyword columns
    return _buildKeywordColumns();
  }

  List<DataColumnConfig> _buildKeywordColumns() {
    return [
      DataColumnConfig(
        id: 'keyword',
        label: 'Keyword',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            row['keyword']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'search_volume',
        label: 'Volume',
        numeric: true,
        sortable: true,
        cellBuilder: (row) => Text(
          _formatNumber(row['search_volume']),
          style: const TextStyle(fontSize: 11),
        ),
        csvFormatter: (value) => value?.toString() ?? '0',
      ),
      DataColumnConfig(
        id: 'competition',
        label: 'Competition',
        sortable: true,
        cellBuilder: (row) => _buildCompetitionChip(row['competition']?.toString() ?? ''),
        csvFormatter: (value) => value?.toString() ?? '',
      ),
      DataColumnConfig(
        id: 'cpc',
        label: 'CPC',
        numeric: true,
        sortable: true,
        cellBuilder: (row) => Text(
          '\$${(row['cpc'] ?? 0).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 11),
        ),
        csvFormatter: (value) => (value ?? 0).toStringAsFixed(2),
      ),
      DataColumnConfig(
        id: 'intent',
        label: 'Intent',
        sortable: true,
        cellBuilder: (row) => Text(
          row['intent']?.toString() ?? 'unknown',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      DataColumnConfig(
        id: 'trend',
        label: 'Trend',
        numeric: true,
        sortable: true,
        cellBuilder: (row) => Text(
          '${(row['trend'] ?? 0).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 11),
        ),
        csvFormatter: (value) => (value ?? 0).toStringAsFixed(1),
      ),
    ];
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final number = value is num ? value : 0;
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildCompetitionChip(String competition) {
    Color color;
    switch (competition.toUpperCase()) {
      case 'LOW':
        color = Colors.green;
        break;
      case 'MEDIUM':
        color = Colors.orange;
        break;
      case 'HIGH':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        competition.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<DataColumnConfig> _buildRankingColumns() {
    return [
      DataColumnConfig(
        id: 'keyword',
        label: 'Keyword',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            row['keyword']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      DataColumnConfig(
        id: 'position',
        label: 'Position',
        numeric: true,
        sortable: true,
        cellBuilder: (row) {
          final position = row['position'];
          if (position == null) {
            return const Text(
              'Not ranking',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            );
          }
          // Color code based on position
          Color positionColor;
          if (position <= 3) {
            positionColor = Colors.green;
          } else if (position <= 10) {
            positionColor = Colors.blue;
          } else if (position <= 20) {
            positionColor = Colors.orange;
          } else {
            positionColor = Colors.grey;
          }
          return Text(
            '#$position',
            style: TextStyle(
              fontSize: 11,
              color: positionColor,
              fontWeight: FontWeight.bold,
            ),
          );
        },
        csvFormatter: (value) => value?.toString() ?? 'Not ranking',
      ),
      DataColumnConfig(
        id: 'url',
        label: 'Ranking URL',
        sortable: true,
        cellBuilder: (row) {
          final url = row['url']?.toString() ?? '';
          if (url.isEmpty) return const Text('', style: TextStyle(fontSize: 11));
          
          // Extract path from URL for display
          try {
            final uri = Uri.parse(url);
            final displayPath = uri.path.length > 30 
                ? '${uri.path.substring(0, 27)}...'
                : uri.path;
            return Text(
              displayPath.isEmpty ? '/' : displayPath,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            );
          } catch (e) {
            return Text(
              url.length > 30 ? '${url.substring(0, 27)}...' : url,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            );
          }
        },
        csvFormatter: (value) => value?.toString() ?? '',
      ),
      DataColumnConfig(
        id: 'title',
        label: 'Page Title',
        sortable: true,
        cellBuilder: (row) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            row['title']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    ];
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
    
    // Start polling for keywords if on keywords tab and no keywords yet
    if (_selectedProjectTab == ProjectTab.keywords && keywords.isEmpty && _keywordPollingTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startKeywordPolling();
      });
    }
    
    // Stop polling if we have keywords
    if (keywords.isNotEmpty && _keywordPollingTimer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _stopKeywordPolling();
      });
    }

    return DefaultTabController(
      length: 5,
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
                            _selectedProjectTab = ProjectTab.chat;
                            _selectedMode = 'agent';
                          });
                          
                          // Switch to chat tab and send initial message
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            DefaultTabController.of(context).animateTo(4); // Chat is the 5th tab (index 4)
                            // Wait a bit for the tab to finish switching, then send message
                            Future.delayed(const Duration(milliseconds: 300)).then((_) {
                              if (mounted) {
                                _messageController.text = "Let's work on my ${project.name} project (${project.targetUrl}).";
                                _sendMessage();
                              }
                            });
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
                      
                      // Start polling if switching to keywords tab with no keywords
                      if (_selectedProjectTab == ProjectTab.keywords && keywords.isEmpty) {
                        _startKeywordPolling();
                      } else {
                        _stopKeywordPolling();
                      }
                    },
                    tabs: [
                      const Tab(text: 'Overview'),
                      const Tab(text: 'Pinboard'),
                      Tab(text: 'Keywords (${keywords.length})'),
                      Tab(text: 'Backlinks (${projectProvider.backlinksData?['total_backlinks'] ?? 0})'),
                      const Tab(text: 'Chat'),
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
                  _buildProjectChatTab(project),
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
    
    // Extract sparkline data from overtime
    List<double>? daSparkline;
    List<double>? backlinksSparkline;
    List<double>? domainsSparkline;
    
    if (overtime.isNotEmpty) {
      daSparkline = overtime.map<double>((point) => (point['da'] ?? 0).toDouble()).toList();
      backlinksSparkline = overtime.map<double>((point) => (point['backlinks'] ?? 0).toDouble()).toList();
      domainsSparkline = overtime.map<double>((point) => (point['referring_domains'] ?? 0).toDouble()).toList();
    }
    
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
                // Backlink Profile Metrics
                Text(
                  'Backlink Profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Domain Authority',
                        domainAuthority.toString(),
                        Icons.shield_outlined,
                        _getDomainAuthorityColor(domainAuthority),
                        sparklineData: daSparkline,
                        showSparklinePlaceholder: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Total Backlinks',
                        _formatNumber(totalBacklinks),
                        Icons.link,
                        Colors.blue[400]!,
                        sparklineData: backlinksSparkline,
                        showSparklinePlaceholder: true,
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
                        sparklineData: domainsSparkline,
                        showSparklinePlaceholder: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Spam Score',
                        _getSpamScore(backlinksData),
                        Icons.security,
                        _getSpamScoreColor(backlinksData),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Keyword Visibility Section
                _buildKeywordVisibilitySection(projectProvider),
                
                // If no data
                if (overtime.isEmpty && totalBacklinks == 0) ...[
                  const SizedBox(height: 24),
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
                          'No Backlink Data Yet',
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
  
  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {List<double>? sparklineData, bool showSparklinePlaceholder = false}) {
    final hasSparkline = sparklineData != null && sparklineData.length >= 2;
    final showPlaceholder = !hasSparkline && showSparklinePlaceholder;
    
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasSparkline || showPlaceholder) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: hasSparkline
                          ? CustomPaint(
                              painter: SparklinePainter(
                                sparklineData!,
                                color.withOpacity(0.6),
                                invertY: false, // For metrics, higher is better
                              ),
                            )
                          : CustomPaint(
                              painter: NoDataSparklinePainter(
                                color.withOpacity(0.3),
                              ),
                            ),
                    ),
                  ),
                ],
              ],
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
  
  
  String _getSpamScore(Map<String, dynamic>? backlinksData) {
    if (backlinksData == null) return 'N/A';
    
    // Try to get spam score from backlinks data
    final backlinks = backlinksData['backlinks'] as List?;
    if (backlinks == null || backlinks.isEmpty) return 'N/A';
    
    // Calculate average spam score from backlinks
    int totalSpam = 0;
    int count = 0;
    for (var link in backlinks) {
      final spam = link['spam_score'];
      if (spam != null) {
        totalSpam += spam as int;
        count++;
      }
    }
    
    if (count == 0) return 'N/A';
    final avgSpam = (totalSpam / count).round();
    return '$avgSpam%';
  }
  
  Color _getSpamScoreColor(Map<String, dynamic>? backlinksData) {
    if (backlinksData == null) return Colors.grey[600]!;
    
    final scoreStr = _getSpamScore(backlinksData);
    if (scoreStr == 'N/A') return Colors.grey[600]!;
    
    final score = int.tryParse(scoreStr.replaceAll('%', '')) ?? 0;
    
    if (score >= 60) return Colors.red[600]!;
    if (score >= 30) return Colors.orange[600]!;
    if (score >= 10) return Colors.yellow[700]!;
    return Colors.green[600]!;
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
  
  Widget _buildKeywordVisibilitySection(ProjectProvider projectProvider) {
    final keywords = projectProvider.trackedKeywords;
    
    if (keywords.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keyword Visibility',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No tracked keywords yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Calculate stats
    int totalKeywords = keywords.length;
    int top3Keywords = keywords.where((k) => k.currentPosition != null && k.currentPosition! <= 3).length;
    int top10Keywords = keywords.where((k) => k.currentPosition != null && k.currentPosition! <= 10).length;
    
    // Calculate average position
    final rankedKeywords = keywords.where((k) => k.currentPosition != null).toList();
    double avgPosition = 0;
    if (rankedKeywords.isNotEmpty) {
      avgPosition = rankedKeywords.map((k) => k.currentPosition!).reduce((a, b) => a + b) / rankedKeywords.length;
    }
    
    // Calculate not ranking vs ranking
    int ranking = rankedKeywords.length;
    int notRanking = totalKeywords - ranking;
    
    // Calculate average position over time for sparklines (if we have historical data)
    List<double>? avgPositionSparkline;
    if (rankedKeywords.isNotEmpty && rankedKeywords.any((k) => k.rankingHistory.length >= 2)) {
      // Get max history length to align all data points
      final maxHistoryLength = rankedKeywords.map((k) => k.rankingHistory.length).reduce((a, b) => a > b ? a : b);
      
      // Calculate average position at each time point
      avgPositionSparkline = List.generate(maxHistoryLength, (index) {
        final positions = rankedKeywords
            .where((k) => k.rankingHistory.length > index && k.rankingHistory[index].position != null)
            .map((k) => k.rankingHistory[index].position!.toDouble())
            .toList();
        
        if (positions.isEmpty) return avgPosition;
        return positions.reduce((a, b) => a + b) / positions.length;
      });
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keyword Visibility',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Keywords',
                totalKeywords.toString(),
                Icons.key,
                Colors.indigo[400]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Top 3 Rankings',
                top3Keywords.toString(),
                Icons.emoji_events,
                Colors.amber[600]!,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Top 10 Rankings',
                top10Keywords.toString(),
                Icons.trending_up,
                Colors.green[600]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Avg Position',
                rankedKeywords.isEmpty ? 'N/A' : avgPosition.toStringAsFixed(1),
                Icons.analytics_outlined,
                _getAvgPositionColor(avgPosition),
                sparklineData: avgPositionSparkline,
                showSparklinePlaceholder: true,
              ),
            ),
          ],
        ),
        if (totalKeywords > 0) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility, color: Colors.green[600], size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '$ranking',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ranking',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (notRanking > 0)
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.visibility_off, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '$notRanking',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Not Ranking',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Color _getAvgPositionColor(double avgPosition) {
    if (avgPosition == 0) return Colors.grey[600]!;
    if (avgPosition <= 3) return Colors.amber[600]!;
    if (avgPosition <= 10) return Colors.green[600]!;
    if (avgPosition <= 20) return Colors.blue[600]!;
    if (avgPosition <= 50) return Colors.orange[600]!;
    return Colors.grey[600]!;
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
  final Set<String> _activatingKeywordIds = {}; // Track keywords being activated
  bool _isDeletingKeywords = false;
  String? _hoveredKeywordId; // Track which specific keyword is being hovered
  
  // Sorting and filtering state for keywords
  String _keywordSortBy = 'position'; // position, name, volume, status
  bool _keywordSortAscending = true;
  String _keywordFilter = 'all'; // all, tracking, suggestions
  String _keywordSearchQuery = ''; // Search query for keywords

  // Sorting and filtering state for backlinks
  String _backlinkSortBy = 'rank'; // rank, anchor, source
  bool _backlinkSortAscending = false; // Default: highest rank first
  String _backlinkFilter = 'all'; // all, follow, nofollow
  String _backlinkSearchQuery = ''; // Search query for backlinks

  List<TrackedKeyword> _filterAndSortKeywords(List<TrackedKeyword> keywords) {
    // Apply search filter
    List<TrackedKeyword> filtered = keywords;
    if (_keywordSearchQuery.isNotEmpty) {
      filtered = filtered.where((k) => 
        k.keyword.toLowerCase().contains(_keywordSearchQuery.toLowerCase())
      ).toList();
    }
    
    // Apply status filter
    switch (_keywordFilter) {
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
      switch (_keywordSortBy) {
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
      
      return _keywordSortAscending ? comparison : -comparison;
    });
    
    return filtered;
  }

  List<Map<String, dynamic>> _filterAndSortBacklinks(List<Map<String, dynamic>> backlinks) {
    // Apply search filter (search in source URL and anchor text)
    List<Map<String, dynamic>> filtered = backlinks;
    if (_backlinkSearchQuery.isNotEmpty) {
      final query = _backlinkSearchQuery.toLowerCase();
      filtered = filtered.where((b) {
        final sourceUrl = (b['url_from'] as String? ?? '').toLowerCase();
        final anchorText = (b['anchor'] as String? ?? '').toLowerCase();
        return sourceUrl.contains(query) || anchorText.contains(query);
      }).toList();
    }
    
    // Apply link type filter
    switch (_backlinkFilter) {
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
      switch (_backlinkSortBy) {
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
      
      return _backlinkSortAscending ? comparison : -comparison;
    });
    
    return filtered;
  }

  Widget _buildKeywordsTab(ProjectProvider projectProvider, List<TrackedKeyword> keywords) {
    // Apply filtering and sorting
    final filteredKeywords = _filterAndSortKeywords(keywords);
    
    return projectProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : keywords.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CliSpinner(
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Auto-detecting keywords',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ThinkingIndicator(
                          text: '',
                          fontSize: 20,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analyzing your website to suggest relevant keywords.\nThis may take 1-5 minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You can add keywords manually from the chat while you wait',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Search, filter and sort controls (inline, compact)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Search bar (compact)
                        SizedBox(
                          width: 250,
                          height: 36,
                          child: TextField(
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search keywords...',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 16),
                              suffixIcon: _keywordSearchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() => _keywordSearchQuery = '');
                                      },
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _keywordSearchQuery = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Filter chips (compact)
                        Text(
                          'Show:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('All', style: TextStyle(fontSize: 12)),
                          selected: _keywordFilter == 'all',
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          labelPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _keywordFilter = 'all');
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Tracking', style: TextStyle(fontSize: 12)),
                          selected: _keywordFilter == 'tracking',
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          labelPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _keywordFilter = 'tracking');
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Suggestions', style: TextStyle(fontSize: 12)),
                          selected: _keywordFilter == 'suggestions',
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          labelPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _keywordFilter = 'suggestions');
                            }
                          },
                        ),
                        const Spacer(),
                        // Sort dropdown (compact)
                        Text(
                          'Sort by:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _keywordSortBy,
                          underline: Container(),
                          isDense: true,
                          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                          items: const [
                            DropdownMenuItem(value: 'position', child: Text('Position')),
                            DropdownMenuItem(value: 'name', child: Text('Name')),
                            DropdownMenuItem(value: 'volume', child: Text('Search Volume')),
                            DropdownMenuItem(value: 'status', child: Text('Status')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _keywordSortBy = value);
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            _keywordSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16,
                          ),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() => _keywordSortAscending = !_keywordSortAscending);
                          },
                          tooltip: _keywordSortAscending ? 'Ascending' : 'Descending',
                        ),
                      ],
                    ),
                  ),
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
                          // Show "Start Tracking" button if any suggestions are selected
                          if (_selectedKeywordIds.any((id) => 
                              keywords.any((kw) => kw.id == id && kw.isSuggestion)))
                            TextButton.icon(
                              onPressed: () {
                                final selectedSuggestions = _selectedKeywordIds
                                    .where((id) => keywords.any((kw) => kw.id == id && kw.isSuggestion))
                                    .toList();
                                
                                final count = selectedSuggestions.length;
                                
                                // Clear selection and mark as activating
                                setState(() {
                                  _selectedKeywordIds.clear();
                                  _activatingKeywordIds.addAll(selectedSuggestions);
                                });
                                
                                // Show activating message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Activating $count keyword(s)...'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                                
                                // Activate in background
                                () async {
                                  try {
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    
                                    // Activate all selected suggestions
                                    for (final id in selectedSuggestions) {
                                      await authProvider.apiService.toggleKeywordActive(id);
                                    }
                                    
                                    // Reload keywords
                                    if (mounted) {
                                      await projectProvider.loadTrackedKeywords(
                                        authProvider.apiService,
                                        projectProvider.selectedProject!.id,
                                      );
                                      
                                      // Clear activating state
                                      setState(() {
                                        _activatingKeywordIds.removeAll(selectedSuggestions);
                                      });
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✓ Activated $count keyword(s) for tracking'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      // Clear activating state on error
                                      setState(() {
                                        _activatingKeywordIds.removeAll(selectedSuggestions);
                                      });
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to activate keywords: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }();
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Tracking'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green,
                              ),
                            ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: (_isDeletingKeywords || _selectedKeywordIds.isEmpty) ? null : () async {
                              // Capture everything we need before any async operations
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              final apiService = context.read<ApiService>();
                              final projectProvider = context.read<ProjectProvider>();
                              final keywordIds = _selectedKeywordIds.toList();
                              final count = keywordIds.length;
                              
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Remove Keywords'),
                                  content: Text('Permanently remove $count keyword(s)?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(dialogContext, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(dialogContext).colorScheme.error,
                                      ),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm != true) return;
                              if (!mounted) return;
                              if (_isDeletingKeywords) return; // Prevent double-tap
                              
                              setState(() {
                                _isDeletingKeywords = true;
                              });
                              
                              try {
                                // Delete keywords
                                await projectProvider.deleteMultipleKeywords(
                                  apiService,
                                  keywordIds,
                                );
                                
                                if (!mounted) return;
                                
                                // Clear selection after successful deletion
                                setState(() {
                                  _selectedKeywordIds.clear();
                                  _isDeletingKeywords = false;
                                });
                                
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('$count keyword(s) removed'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                
                                setState(() {
                                  _isDeletingKeywords = false;
                                });
                                
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to remove keywords: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: _isDeletingKeywords 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_outline),
                            label: Text(_isDeletingKeywords ? 'Removing...' : 'Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Keywords list
                  Expanded(
                    child: filteredKeywords.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No keywords match your filters',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0),
                          itemCount: filteredKeywords.length + 1, // +1 for the Add Keyword button
                          itemBuilder: (context, index) {
                            // Add Keyword button at the end
                            if (index == filteredKeywords.length) {
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

                            final keyword = filteredKeywords[index];
                            final isSelected = _selectedKeywordIds.contains(keyword.id);
                            final isHovered = _hoveredKeywordId == keyword.id;
                            // Show checkbox if: this item is hovered OR any item is selected
                            final showCheckbox = isHovered || _selectedKeywordIds.isNotEmpty;
                            
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _hoveredKeywordId = keyword.id),
                              onExit: (_) => setState(() => _hoveredKeywordId = null),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                      : (isHovered ? Theme.of(context).hoverColor.withOpacity(0.05) : Colors.transparent),
                                  borderRadius: BorderRadius.circular(8),
                                  border: !isSelected
                                      ? Border.all(
                                          color: Theme.of(context).dividerColor.withOpacity(0.2),
                                          width: 1,
                                        )
                                      : null,
                                ),
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                    child: Row(
                                      children: [
                                        // Checkbox for multi-select (always reserve space, fade in/out)
                                        SizedBox(
                                          width: 48,
                                          child: AnimatedOpacity(
                                            opacity: showCheckbox ? 1.0 : 0.0,
                                            duration: const Duration(milliseconds: 150),
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: Checkbox(
                                                value: isSelected,
                                                onChanged: showCheckbox
                                                    ? (value) {
                                                        setState(() {
                                                          if (value == true) {
                                                            _selectedKeywordIds.add(keyword.id);
                                                          } else {
                                                            _selectedKeywordIds.remove(keyword.id);
                                                          }
                                                        });
                                                      }
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Keyword info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      keyword.keyword,
                                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  if (keyword.isSuggestion)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.lightbulb_outline,
                                                            size: 12,
                                                            color: Colors.orange[700],
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Suggestion',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.orange[700],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (keyword.source == 'auto_detected' && keyword.isActive)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.auto_awesome,
                                                            size: 12,
                                                            color: Colors.blue,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Auto-Detected',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.blue,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  // Tracking status indicator
                                                  Builder(
                                                    builder: (context) {
                                                      final isActivating = _activatingKeywordIds.contains(keyword.id);
                                                      final statusColor = isActivating 
                                                          ? Colors.orange
                                                          : (keyword.isActive ? Colors.green : Colors.grey);
                                                      final statusText = isActivating
                                                          ? 'Activating...'
                                                          : (keyword.isActive ? 'Tracking' : 'Not Tracking');
                                                      final statusIcon = isActivating
                                                          ? Icons.sync
                                                          : (keyword.isActive ? Icons.show_chart : Icons.pause_circle_outline);
                                                      
                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: statusColor.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (isActivating)
                                                              SizedBox(
                                                                width: 12,
                                                                height: 12,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 1.5,
                                                                  valueColor: AlwaysStoppedAnimation<Color>(statusColor[700]!),
                                                                ),
                                                              )
                                                            else
                                                              Icon(
                                                                statusIcon,
                                                                size: 12,
                                                                color: statusColor[700],
                                                              ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              statusText,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: statusColor[700],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 12),
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
                                    // Sparkline chart from ranking history
                                    Builder(
                                      builder: (context) {
                                        if (keyword.rankingHistory.length >= 2) {
                                          // Extract positions for sparkline
                                          final positions = keyword.rankingHistory
                                              .map((point) => point.position)
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
                                        // Show placeholder when no data
                                        return SizedBox(
                                          width: 80,
                                          height: 40,
                                          child: CustomPaint(
                                            painter: NoDataSparklinePainter(
                                              Colors.grey.withOpacity(0.3),
                                            ),
                                          ),
                                        );
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
                                          keyword.currentPosition?.toString() ?? '--',
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
    final allBacklinks = (data?['backlinks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final filteredBacklinks = _filterAndSortBacklinks(allBacklinks);
    final totalBacklinks = data?['total_backlinks'] ?? 0;
    final referringDomains = data?['referring_domains'] ?? 0;
    final domainAuthority = data?['domain_authority'] ?? 0;
    final analyzedAt = data?['analyzed_at'] as String?;

    if (allBacklinks.isEmpty) {
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
        // Search, Filter, and Sort Controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Search field
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search backlinks...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _backlinkSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() => _backlinkSearchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _backlinkSearchQuery = value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Filter chips
              Wrap(
                spacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('All', style: TextStyle(fontSize: 12)),
                    selected: _backlinkFilter == 'all',
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    labelPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _backlinkFilter = 'all');
                      }
                    },
                  ),
                  const SizedBox(width: 2),
                  ChoiceChip(
                    label: const Text('Follow', style: TextStyle(fontSize: 12)),
                    selected: _backlinkFilter == 'follow',
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    labelPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _backlinkFilter = 'follow');
                      }
                    },
                  ),
                  const SizedBox(width: 2),
                  ChoiceChip(
                    label: const Text('Nofollow', style: TextStyle(fontSize: 12)),
                    selected: _backlinkFilter == 'nofollow',
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    labelPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _backlinkFilter = 'nofollow');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(width: 8),
              
              // Sort dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButton<String>(
                  value: _backlinkSortBy,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 13),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'rank', child: Text('Rank')),
                    DropdownMenuItem(value: 'anchor', child: Text('Anchor')),
                    DropdownMenuItem(value: 'source', child: Text('Source')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _backlinkSortBy = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              
              // Sort direction
              IconButton(
                icon: Icon(
                  _backlinkSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: _backlinkSortAscending ? 'Ascending' : 'Descending',
                onPressed: () {
                  setState(() => _backlinkSortAscending = !_backlinkSortAscending);
                },
              ),
            ],
          ),
        ),

        // Separator line
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),

        // List of backlinks
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0),
            itemCount: filteredBacklinks.length,
            itemBuilder: (context, index) {
              final backlink = filteredBacklinks[index];
              final sourceUrl = backlink['url_from'] as String?;
              final targetUrl = backlink['url_to'] as String?;
              final anchorText = backlink['anchor'] as String?;
              final inlinkRank = backlink['inlink_rank'] as num?;
              final isNofollow = backlink['nofollow'] == true;

              return InkWell(
                onTap: () async {
                  if (sourceUrl != null) {
                    final uri = Uri.parse(sourceUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      children: [
                        // Leading icon
                        Container(
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
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Main content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sourceUrl ?? 'Unknown source',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.open_in_new,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                              if (anchorText != null && anchorText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Anchor: "$anchorText"',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (inlinkRank != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Quality: ${inlinkRank.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Trailing badge
                        if (isNofollow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NOFOLLOW',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
    );
  }

  Widget _buildProjectChatTab(Project project) {
    final chatProvider = context.watch<ChatProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: chatProvider.messages.length,
            itemBuilder: (context, index) {
              final message = chatProvider.messages[index];
              return MessageBubble(message: message);
            },
          ),
        ),
        
        // Input area - reuse the same design as main chat
        Padding(
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
                        hintText: 'Ask about ${project.name}...',
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
                                  child: IconButton(
                                    onPressed: () async {
                                      // Pin current conversation to this project
                                      await _pinConversationToProject(project.id);
                                    },
                                    icon: Icon(
                                      Icons.bookmark_border,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Pin to ${project.name}',
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
class NoDataSparklinePainter extends CustomPainter {
  final Color lineColor;

  NoDataSparklinePainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw a dashed horizontal line in the middle
    final y = size.height / 2;
    final dashWidth = 4.0;
    final dashSpace = 4.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(NoDataSparklinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> positions;
  final Color lineColor;
  final bool invertY; // If true, lower values are better (rankings). If false, higher is better (metrics)

  SparklinePainter(this.positions, this.lineColor, {this.invertY = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Find min and max for scaling
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
      final normalizedPos = (positions[i] - minPos) / range;
      
      // For invertY=true (rankings): lower position (1) should be at top (small Y)
      // For invertY=false (metrics): higher value should be at top (small Y)
      final y = invertY 
          ? normalizedPos * size.height  // Lower value = top
          : (1 - normalizedPos) * size.height;  // Higher value = top

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

