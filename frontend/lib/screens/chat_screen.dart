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
import '../widgets/sortable_data_table.dart';
import '../widgets/suggestion_buttons.dart';
import '../widgets/quick_tip.dart';
import '../widgets/competition_chip.dart';
import '../widgets/trend_indicator.dart';
import '../widgets/chart_painters.dart';
import '../widgets/expandable_audit_item.dart';
import '../widgets/metric_card.dart';
import '../dialogs/project_dialogs.dart';
import '../utils/formatting_utils.dart';
import 'conversations_view.dart';
import 'projects_list_view.dart';
import 'tabs/backlinks_tab.dart';
import 'tabs/keywords_tab.dart';
import 'tabs/pinboard_tab.dart';
import 'tabs/site_audit_tab.dart';
import '../utils/color_helpers.dart';
import '../utils/keyword_filters.dart';
import '../utils/backlink_filters.dart';
import '../config/table_column_configs.dart';
import 'dart:html' as html;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum ViewState { chat, conversations, projects }
enum ProjectViewState { list, detail }
enum ProjectTab { overview, keywords, backlinks, siteAudit, pinboard }
enum SeoAgentTab { dashboard, contentLibrary, activity }
enum ProjectMode { seo, seoAgent }

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _hasShownWelcomeModal = false;
  bool _hasLoadedProjects = false;
  bool _shouldCancelRequest = false;
  ViewState _currentView = ViewState.chat;
  ProjectViewState _projectViewState = ProjectViewState.list;
  ProjectTab _selectedProjectTab = ProjectTab.keywords;
  ProjectMode _projectMode = ProjectMode.seo;
  SeoAgentTab _selectedSeoAgentTab = SeoAgentTab.dashboard;
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
      
      // Auto-focus message input with delay to ensure widget is built
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
    _keywordPollingTimer?.cancel();
    super.dispose();
  }

  /// Helper method to switch to chat view and auto-focus input
  void _switchToChatView() {
    setState(() {
      _currentView = ViewState.chat;
    });
    // Request focus after frame is built
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _currentView == ViewState.chat) {
        _messageFocusNode.requestFocus();
      }
    });
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
    // Refocus input after stopping generation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _currentView == ViewState.chat) {
        _messageFocusNode.requestFocus();
      }
    });
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
      // Refocus input after message is sent/completed
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _currentView == ViewState.chat) {
          _messageFocusNode.requestFocus();
        }
      });
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
                      _switchToChatView();
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
                    _switchToChatView();
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
                  icon: const Icon(Icons.forum_outlined),
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
                // Only show mode toggle when viewing a project
                if (_currentView == ViewState.projects && _projectViewState == ProjectViewState.detail) ...[
                  const SizedBox(height: 24),
                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      thickness: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mode toggle - SEO
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _projectMode = ProjectMode.seo;
                      });
                    },
                    icon: const Icon(Icons.analytics_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: _projectMode == ProjectMode.seo
                          ? const Color(0xFFFFC107).withOpacity(0.2)
                          : null,
                      foregroundColor: _projectMode == ProjectMode.seo
                          ? const Color(0xFFFFC107)
                          : null,
                    ),
                    iconSize: 24,
                    tooltip: 'SEO Analytics',
                  ),
                  const SizedBox(height: 8),
                  // Mode toggle - SEO Agent
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _projectMode = ProjectMode.seoAgent;
                      });
                    },
                    icon: const Icon(Icons.auto_awesome),
                    style: IconButton.styleFrom(
                      backgroundColor: _projectMode == ProjectMode.seoAgent
                          ? const Color(0xFFFFC107).withOpacity(0.2)
                          : null,
                      foregroundColor: _projectMode == ProjectMode.seoAgent
                          ? const Color(0xFFFFC107)
                          : null,
                    ),
                    iconSize: 24,
                    tooltip: 'SEO Agent',
                  ),
                ],
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
                      focusNode: _messageFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Ask me to analyze a website, research keywords, check rankings...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      cursorWidth: 10,
                      cursorHeight: 18,
                      cursorRadius: Radius.zero,
                      cursorColor: Theme.of(context).colorScheme.primary.withOpacity(0.6),
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
              SuggestionButtons(
                onSuggestionTap: (message) {
                  _messageController.text = message;
                  _sendMessage();
                },
              ),
            ],
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
                  focusNode: _messageFocusNode,
                    decoration: const InputDecoration(
                        hintText: 'Ask me to analyze a website, research keywords, check rankings...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  cursorWidth: 10,
                  cursorHeight: 18,
                  cursorRadius: Radius.zero,
                  cursorColor: Theme.of(context).colorScheme.primary.withOpacity(0.6),
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
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Show all status steps with checkmarks for completed
                                              for (int i = 0; i < chatProvider.statusSteps.length; i++)
                                                Padding(
                                                  padding: EdgeInsets.only(bottom: i < chatProvider.statusSteps.length - 1 ? 6 : 0),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      // Show checkmark for completed steps, spinner for current
                                                      if (i < chatProvider.statusSteps.length - 1)
                                                        Icon(
                                                          Icons.check_circle,
                                                          size: 16,
                                                          color: Theme.of(context).colorScheme.primary,
                                                        )
                                                      else
                                                        CliSpinner(
                                                          size: 13,
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        chatProvider.statusSteps[i],
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          color: i < chatProvider.statusSteps.length - 1
                                                              ? Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)
                                                              : Theme.of(context).textTheme.bodySmall?.color,
                                                        ),
                                                      ),
                                                    ],
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
    
    // Wrap in Stack and Row to support side panel and minimize button
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: chatContent,
            ),
            if (chatProvider.dataPanelOpen && !chatProvider.dataPanelMinimized)
              DataPanel(
                data: chatProvider.dataPanelData,
                columns: _buildDataPanelColumns(chatProvider.dataPanelTitle),
                title: chatProvider.dataPanelTitle,
                onClose: () => chatProvider.closeDataPanel(),
                onMinimize: () => chatProvider.minimizeDataPanel(),
                csvFilename: '${chatProvider.dataPanelTitle.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv',
                // Tabbed view support (for conversation results)
                tabs: chatProvider.dataPanelTabs,
                tabColumns: chatProvider.dataPanelTabs != null 
                    ? _buildTabColumns(chatProvider.dataPanelTabs!)
                    : null,
                dataPanelUrl: chatProvider.dataPanelUrl,
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
                    keyword['ad_competition'] as String? ?? keyword['competition'] as String?,
                    keyword['seo_difficulty'] as int?,
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
      ),
      // Floating restore button when panel is minimized
      if (chatProvider.dataPanelOpen && chatProvider.dataPanelMinimized)
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () => chatProvider.maximizeDataPanel(),
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black87,
            icon: const Icon(Icons.table_chart),
            label: Text(
              '${chatProvider.conversationResults.length} Result${chatProvider.conversationResults.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            tooltip: 'Show conversation results',
          ),
        ),
      ],
    );
  }

  // Delegate to TableColumnConfigs
  List<DataColumnConfig> _buildDataPanelColumns(String title) => 
      TableColumnConfigs.buildDataPanelColumns(title);
  
  Map<String, List<DataColumnConfig>> _buildTabColumns(Map<String, List<Map<String, dynamic>>> tabs) =>
      TableColumnConfigs.buildTabColumns(tabs);

  // Simple helper delegates
  String _formatNumber(dynamic value) => FormattingUtils.formatNumber(value);
  String _formatAnalyzedDate(String dateStr) => FormattingUtils.formatAnalyzedDate(dateStr);
  Widget _buildCompetitionChip(String competition) => CompetitionChip(competition: competition);

  Widget _buildConversationsView() => ConversationsView(onSwitchToChatView: _switchToChatView);

  Widget _buildProjectsView() {
    switch (_projectViewState) {
      case ProjectViewState.list:
        return _buildProjectsListView();
      case ProjectViewState.detail:
        return _buildProjectDetailView();
    }
  }

  Widget _buildProjectsListView() => ProjectsListView(
    onCreateProject: _showCreateProjectDialog,
    onProjectSelected: () => setState(() => _projectViewState = ProjectViewState.detail),
  );
  
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
                    // Project info with action buttons in same row
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
                      // Chat button - prominent call to action
                      FilledButton.icon(
                        onPressed: () {
                          // Start a new conversation with project context
                          final chatProvider = context.read<ChatProvider>();
                          final project = projectProvider.selectedProject!;
                          chatProvider.startNewConversation();
                          MessageBubble.clearAnimationCache();
                          
                          _switchToChatView();
                          
                          // Switch to main chat and send initial message
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Future.delayed(const Duration(milliseconds: 300)).then((_) {
                              if (mounted) {
                                if (_projectMode == ProjectMode.seoAgent) {
                                  _messageController.text = "Help me set up SEO Agent for ${project.name}";
                                } else {
                                  _messageController.text = "Let's work on my ${project.name} project (${project.targetUrl}).";
                                }
                                _sendMessage();
                              }
                            });
                          });
                        },
                        icon: Icon(_projectMode == ProjectMode.seoAgent ? Icons.auto_awesome : Icons.forum_outlined, size: 20),
                        label: Text(_projectMode == ProjectMode.seoAgent ? 'Setup SEO Agent' : 'Work on SEO Strategy'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                        const SizedBox(width: 12),
                        // Mode toggle button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _projectMode = _projectMode == ProjectMode.seo
                                    ? ProjectMode.seoAgent
                                    : ProjectMode.seo;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107).withOpacity(0.15),
                                border: Border.all(
                                  color: const Color(0xFFFFC107).withOpacity(0.4),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _projectMode == ProjectMode.seo 
                                        ? Icons.analytics_outlined 
                                        : Icons.auto_awesome,
                                    size: 18,
                                    color: const Color(0xFFFFC107),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _projectMode == ProjectMode.seo 
                                        ? 'SEO Analytics' 
                                        : 'SEO Agent',
                                    style: const TextStyle(
                                      color: Color(0xFFFFC107),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.swap_horiz,
                                    size: 16,
                                    color: Color(0xFFFFC107),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 8),
                    
                    // Tabs with counts (only show in SEO mode)
                    if (_projectMode == ProjectMode.seo)
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
                          Tab(text: 'Keywords (${keywords.length})'),
                          Tab(text: 'Backlinks (${projectProvider.backlinksData?['total_backlinks'] ?? 0})'),
                          const Tab(text: 'Site Audit'),
                          const Tab(text: 'Pinboard'),
                        ],
                      ),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: _projectMode == ProjectMode.seo
                    ? TabBarView(
                        physics: const NeverScrollableScrollPhysics(), // Disable swipe
                        children: [
                          _buildOverviewTab(project, projectProvider),
                          _buildKeywordsTab(projectProvider, keywords),
                          _buildBacklinksTab(project),
                          SiteAuditTab(
                            project: project,
                            messageController: _messageController,
                            onSwitchToChatView: _switchToChatView,
                            onTabChanged: (tab) => setState(() => _selectedProjectTab = tab),
                          ),
                          PinboardTab(project: project),
                        ],
                      )
                    : _buildSeoAgentView(project, projectProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeoAgentView(Project project, ProjectProvider projectProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check if WordPress is connected (mock for now)
    final bool isWordPressConnected = false;
    final bool hasSeenIntro = false; // TODO: Track if user has seen intro
    
    // Show intro if not connected and haven't seen it
    if (!isWordPressConnected && !hasSeenIntro) {
      return _buildSeoAgentIntro();
    }
    
    // Show monitoring tabs when connected
    return Column(
      children: [
        // SEO Agent Tabs
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            onTap: (index) {
              setState(() {
                _selectedSeoAgentTab = SeoAgentTab.values[index];
              });
            },
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Content Library'),
              Tab(text: 'Activity'),
            ],
          ),
        ),
        
        // Tab Content
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSeoAgentDashboard(project),
              _buildContentLibrary(project),
              _buildActivityTab(project),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeoAgentIntro() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFC107).withOpacity(0.2),
                      const Color(0xFFFF9800).withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFC107).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: Color(0xFFFFC107),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                'SEO Agent',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              
              const SizedBox(height: 8),
              
              // Description
              Text(
                'AI-powered content generation and WordPress publishing automation',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Features
              _buildFeatureItem(
                context,
                icon: Icons.article_outlined,
                title: 'Generate SEO Content',
                description: 'Create high-quality articles optimized for your target keywords',
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureItem(
                context,
                icon: Icons.publish,
                title: 'Auto-Publish to WordPress',
                description: 'Seamlessly publish content directly to your WordPress site',
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureItem(
                context,
                icon: Icons.trending_up,
                title: 'Track Performance',
                description: 'Monitor your content\'s impact on rankings and traffic',
              ),
              
              const SizedBox(height: 48),
              
              // CTA Button
              ElevatedButton(
                onPressed: () {
                  // Switch to chat view with setup message
                  final chatProvider = context.read<ChatProvider>();
                  final projectProvider = context.read<ProjectProvider>();
                  final project = projectProvider.selectedProject!;
                  
                  chatProvider.startNewConversation();
                  MessageBubble.clearAnimationCache();
                  
                  setState(() {
                    _currentView = ViewState.chat;
                  });
                  
                  // Send setup message
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Future.delayed(const Duration(milliseconds: 300)).then((_) {
                      if (mounted) {
                        _messageController.text = "Help me set up SEO Agent for ${project.name}";
                        _sendMessage();
                      }
                    });
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  "Let's Start",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 24,
            color: const Color(0xFFFFC107),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Project project, ProjectProvider projectProvider) {
    final backlinksData = projectProvider.backlinksData;
    final keywords = projectProvider.trackedKeywords;
    final authProvider = context.watch<AuthProvider>();
    
    return FutureBuilder<Map<String, dynamic>>(
      future: authProvider.apiService.get('/chat/project/${project.id}/technical-audits'),
      builder: (context, snapshot) {
        final audits = (snapshot.data?['audits'] as List?) ?? [];
        
        // Extract backlink metrics
        final domainAuthority = backlinksData?['domain_authority'] ?? 0;
        final totalBacklinks = backlinksData?['total_backlinks'] ?? 0;
        final overtime = backlinksData?['overtime'] as List? ?? [];
        
        // Extract sparkline data from overtime
        List<double>? daSparkline;
        List<double>? backlinksSparkline;
        
        if (overtime.isNotEmpty) {
          daSparkline = overtime.map<double>((point) => (point['da'] ?? 0).toDouble()).toList();
          backlinksSparkline = overtime.map<double>((point) => (point['backlinks'] ?? 0).toDouble()).toList();
        }
        
        // Calculate average ranking from keywords
        final rankedKeywords = keywords.where((k) => k.currentPosition != null).toList();
        double avgPosition = 0;
        if (rankedKeywords.isNotEmpty) {
          avgPosition = rankedKeywords.map((k) => k.currentPosition!).reduce((a, b) => a + b) / rankedKeywords.length;
        }
        
        // Get latest audit performance
        int performanceScore = 0;
        List<double>? perfSparkline;
        if (audits.isNotEmpty) {
          performanceScore = audits.first['performance_score'] ?? 0;
          
          // Build sparkline from audit history
          if (audits.length >= 2) {
            perfSparkline = audits.reversed.take(10).map<double>((audit) => 
              (audit['performance_score'] ?? 0).toDouble()
            ).toList();
          }
        }
        
        // Calculate avg position sparkline
        List<double>? avgPositionSparkline;
        if (rankedKeywords.isNotEmpty && rankedKeywords.any((k) => k.rankingHistory.length >= 2)) {
          final maxHistoryLength = rankedKeywords.map((k) => k.rankingHistory.length).reduce((a, b) => a > b ? a : b);
          
          avgPositionSparkline = List.generate(maxHistoryLength, (index) {
            final positions = rankedKeywords
                .where((k) => k.rankingHistory.length > index && k.rankingHistory[index].position != null)
                .map((k) => k.rankingHistory[index].position!.toDouble())
                .toList();
            
            if (positions.isEmpty) return avgPosition;
            return positions.reduce((a, b) => a + b) / positions.length;
          });
        }
        
        return projectProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Health Score (large) + Domain Rating + Referring Domains
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Health Score - Large prominent card
                    Expanded(
                      flex: 2,
                      child: _buildHealthScoreCard(
                        performanceScore,
                        audits,
                        project,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Domain Rating
                    Expanded(
                      child: _buildEnhancedMetricCard(
                        'Domain Rating',
                        domainAuthority.toString(),
                        null,
                        _getDomainAuthorityColor(domainAuthority),
                        sparklineData: daSparkline,
                        maxValue: 100,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Referring domains (using backlinks)
                    Expanded(
                      child: _buildEnhancedMetricCard(
                        'Referring domains',
                        _formatNumber(totalBacklinks),
                        _getBacklinkChange(overtime),
                        Colors.blue[400]!,
                        sparklineData: backlinksSparkline,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Total Visitors
                    Expanded(
                      child: _buildEnhancedMetricCard(
                        'Total visitors',
                        '--',
                        null,
                        Colors.purple[400]!,
                        showMonitoringButton: true,
                        onMonitoringTap: () {
                          // TODO: Implement visitor tracking setup
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Visitor tracking coming soon! Connect Google Analytics or install our tracking script.'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Organic traffic
                    Expanded(
                      child: _buildEnhancedMetricCard(
                        'Organic traffic',
                        '--',
                        null,
                        Colors.teal[400]!,
                        showMonitoringButton: true,
                        onMonitoringTap: () {
                          // TODO: Implement visitor tracking setup
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Organic traffic tracking coming soon! Connect Google Analytics to see visitors from search engines.'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Quick action tips
                if (totalBacklinks == 0 || audits.isEmpty || keywords.isEmpty) ...[
                  Card(
                    color: Colors.blue[900]?.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue[300]),
                              const SizedBox(width: 8),
                              Text(
                                'Quick Start Tips',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[300],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (totalBacklinks == 0)
                            _buildQuickTip('Analyze your backlink profile', 'analyze backlinks for ${project.targetUrl}'),
                          if (audits.isEmpty)
                            _buildQuickTip('Run your first site audit', 'run a site audit for ${project.targetUrl}'),
                          if (keywords.isEmpty)
                            _buildQuickTip('Start tracking keywords', 'track keyword "your keyword" for ${project.targetUrl}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
      },
    );
  }
  
  Widget _buildQuickTip(String title, String command) => QuickTip(title: title, command: command);
  
  Widget _buildPerformanceChart(Project project, List overtime, List<TrackedKeyword> keywords) {
    final authProvider = context.watch<AuthProvider>();
    
    // If no data available, don't show the chart
    if (overtime.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Metric toggles
                Wrap(
                  spacing: 16,
                  children: [
                    _buildMetricToggle('Domain Authority', Colors.purple[400]!, _showDomainAuthority, (value) {
                      setState(() => _showDomainAuthority = value!);
                    }),
                    _buildMetricToggle('Referring Domains', Colors.blue[400]!, _showReferringDomains, (value) {
                      setState(() => _showReferringDomains = value!);
                    }),
                    // Only show Organic Traffic if project is linked to GSC
                    if (project.isGSCLinked)
                      _buildMetricToggle('Organic Traffic', Colors.orange[400]!, _showOrganicTraffic, (value) {
                        setState(() => _showOrganicTraffic = value!);
                      }),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Fetch GSC data and build chart
            FutureBuilder<Map<String, dynamic>?>(
              future: project.isGSCLinked 
                ? authProvider.apiService.get('/chat/project/${project.id}/gsc/analytics')
                : Future.value(null),
              builder: (context, gscSnapshot) {
                final gscData = gscSnapshot.data;
                
                return SizedBox(
                  height: 250,
                  child: _buildMultiLineChart(overtime, gscData, keywords),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricToggle(String label, Color color, bool value, Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            side: BorderSide(color: color, width: 2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: value ? color : Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMultiLineChart(List overtime, Map<String, dynamic>? gscData, List<TrackedKeyword> keywords) {
    // Prepare data points
    List<Map<String, dynamic>> dataPoints = [];
    
    // Add backlinks overtime data
    for (var point in overtime) {
      try {
        dataPoints.add({
          'date': DateTime.parse(point['date']),
          'da': point['da'] ?? 0,
          'referring_domains': point['referring_domains'] ?? 0,
          'backlinks': point['backlinks'] ?? 0,
        });
      } catch (e) {
        // Skip invalid data points
        continue;
      }
    }
    
    // Merge with GSC data if available
    if (gscData != null && gscData['daily_data'] != null) {
      final dailyData = gscData['daily_data'] as List;
      for (var entry in dailyData) {
        try {
          final date = DateTime.parse(entry['date']);
          final existingPoint = dataPoints.firstWhere(
            (p) => (p['date'] as DateTime).year == date.year && 
                   (p['date'] as DateTime).month == date.month && 
                   (p['date'] as DateTime).day == date.day,
            orElse: () => {'date': date, 'da': 0, 'referring_domains': 0, 'backlinks': 0},
          );
          
          existingPoint['clicks'] = entry['clicks'] ?? 0;
          existingPoint['impressions'] = entry['impressions'] ?? 0;
          existingPoint['avg_position'] = entry['position'];
          
          if (!dataPoints.any((p) => p['date'] == date)) {
            dataPoints.add(existingPoint);
          }
        } catch (e) {
          // Skip invalid GSC data points
          continue;
        }
      }
    }
    
    // Sort by date
    dataPoints.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    // Take last 90 days for cleaner visualization
    if (dataPoints.length > 90) {
      dataPoints = dataPoints.sublist(dataPoints.length - 90);
    }
    
    if (dataPoints.isEmpty || dataPoints.length < 2) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[800]!, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'No historical data available yet',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Data will appear here as we track your site over time',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return CustomPaint(
      painter: PerformanceChartPainter(
        dataPoints: dataPoints,
        showDomainAuthority: _showDomainAuthority,
        showReferringDomains: _showReferringDomains,
        showOrganicTraffic: _showOrganicTraffic,
      ),
      child: Container(),
    );
  }
  
  Color _getAvgRankingColor(double avgPosition) => ColorHelpers.getAvgRankingColor(avgPosition);
  
  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {List<double>? sparklineData, bool showSparklinePlaceholder = false, bool invertSparkline = false, String? tooltip, bool compact = false}) {
    return MetricCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      sparklineData: sparklineData,
      showSparklinePlaceholder: showSparklinePlaceholder,
      invertSparkline: invertSparkline,
      tooltip: tooltip,
      compact: compact,
    );
  }
  
  // Enhanced metric card for Ahrefs-style overview
  Widget _buildEnhancedMetricCard(
    String title,
    String value,
    String? change, // e.g., "+2" for referring domains
    Color color, {
    List<double>? sparklineData,
    double? maxValue,
    bool invertSparkline = false,
    bool showMonitoringButton = false,
    VoidCallback? onMonitoringTap,
  }) {
    final hasSparkline = sparklineData != null && sparklineData.length >= 2;
    final showNoData = value == '--' || value == 'N/A';
    
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Value and change indicator
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: showNoData ? Colors.grey[600] : color,
                    height: 1.0,
                  ),
                ),
                if (change != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[600]?.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      change,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[600],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            
            // Start monitoring button
            if (showMonitoringButton && showNoData) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onMonitoringTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.grey[700]!),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Start monitoring',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
            
            // Sparkline graph
            if (hasSparkline) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: CustomPaint(
                  painter: SparklinePainter(
                    sparklineData!,
                    color.withOpacity(0.5),
                    invertY: invertSparkline,
                  ),
                ),
              ),
            ],
            
            // Max value indicator (for things like DR out of 100)
            if (maxValue != null && !hasSparkline) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: double.tryParse(value)! / maxValue,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Health Score Card - Large prominent card
  Widget _buildHealthScoreCard(
    int performanceScore,
    List audits,
    Project project,
  ) {
    final scoreColor = audits.isEmpty 
        ? Colors.grey[600]! 
        : _getScoreColor(performanceScore.toDouble());
    
    // Get breakdown data from latest audit
    int crawled = 0;
    int redirects = 0;
    int broken = 0;
    int blocked = 0;
    
    if (audits.isNotEmpty) {
      final latestAudit = audits.first;
      // You can extract these from your audit data structure
      // For now, using placeholder logic
      crawled = 28; // Example
      redirects = 2;
      broken = 0;
      blocked = 0;
    }
    
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Health Score',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large circular score
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withOpacity(0.2),
                    border: Border.all(
                      color: scoreColor,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      audits.isEmpty ? '--' : performanceScore.toString(),
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // Breakdown details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHealthDetail('Crawled', crawled, Colors.grey[400]!),
                      const SizedBox(height: 8),
                      _buildHealthDetail('Redirects', redirects, Colors.orange[400]!),
                      const SizedBox(height: 8),
                      _buildHealthDetail('Broken', broken, broken > 0 ? Colors.red[400]! : Colors.grey[400]!),
                      const SizedBox(height: 8),
                      _buildHealthDetail('Blocked', blocked, blocked > 0 ? Colors.red[400]! : Colors.grey[400]!),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHealthDetail(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[400],
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  
  String? _getBacklinkChange(List overtime) {
    if (overtime.length < 2) return null;
    
    final latest = overtime.last['backlinks'] as int? ?? 0;
    final previous = overtime[overtime.length - 2]['backlinks'] as int? ?? 0;
    final change = latest - previous;
    
    if (change > 0) return '+$change';
    if (change < 0) return change.toString();
    return null;
  }
  
  Color _getDomainAuthorityColor(int da) => ColorHelpers.getDomainAuthorityColor(da);
  
  Color _getSeoDifficultyColor(int difficulty) => ColorHelpers.getSeoDifficultyColor(difficulty);
  
  
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
    return ColorHelpers.getSpamScoreColor(score);
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
  
  // Performance chart toggles
  bool _showDomainAuthority = true;
  bool _showReferringDomains = true;
  bool _showOrganicTraffic = true;
  bool _showImpressions = false;
  bool _showAvgPosition = false;

  List<TrackedKeyword> _filterAndSortKeywords(List<TrackedKeyword> keywords) {
    return KeywordFilters.filterAndSort(
      keywords,
      searchQuery: _keywordSearchQuery,
      filter: _keywordFilter,
      sortBy: _keywordSortBy,
      sortAscending: _keywordSortAscending,
    );
  }

  List<Map<String, dynamic>> _filterAndSortBacklinks(List<Map<String, dynamic>> backlinks) {
    return BacklinkFilters.filterAndSort(
      backlinks,
      searchQuery: _backlinkSearchQuery,
      filter: _backlinkFilter,
      sortBy: _backlinkSortBy,
      sortAscending: _backlinkSortAscending,
    );
  }

  Widget _buildKeywordsTab(ProjectProvider projectProvider, List<TrackedKeyword> keywords) {
    return KeywordsTab(
      projectProvider: projectProvider,
      keywords: keywords,
      onAddKeyword: () => _showAddKeywordDialog(
        context,
        projectProvider,
        Provider.of<AuthProvider>(context, listen: false),
      ),
    );
  }


  Widget _buildBacklinksTab(Project project) => BacklinksTab(project: project);


  Widget _buildWordPressOnboarding(Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final siteUrlController = TextEditingController();
    final usernameController = TextEditingController();
    final appPasswordController = TextEditingController();
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFC107).withOpacity(0.1),
                      const Color(0xFFFF9800).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFC107).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.integration_instructions,
                      size: 64,
                      color: const Color(0xFFFFC107),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connect WordPress',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate SEO-optimized blog posts and publish directly to your WordPress site',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Connection Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'WordPress Site Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Site URL
                    TextField(
                      controller: siteUrlController,
                      decoration: InputDecoration(
                        labelText: 'Site URL',
                        hintText: 'https://yourblog.com',
                        prefixIcon: const Icon(Icons.language),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Username
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'admin',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Application Password
                    TextField(
                      controller: appPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Application Password',
                        hintText: 'xxxx xxxx xxxx xxxx',
                        prefixIcon: const Icon(Icons.key_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'Generate this in WordPress: Users → Profile → Application Passwords',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Connect Button
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement WordPress connection
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connecting to WordPress...'),
                            backgroundColor: Color(0xFFFFC107),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Connect WordPress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Help Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF2196F3),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Application Passwords are a secure way to connect without exposing your main password. Learn how to create one in WordPress.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.blue[300] : Colors.blue[700],
                            ),
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

  Widget _buildSeoAgentDashboard(Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Mock data
    final mockDrafts = 3;
    final mockScheduled = 5;
    final mockPublished = 12;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection Status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected to WordPress',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'https://yourblog.com',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Switch to chat to manage settings
                    setState(() {
                      _currentView = ViewState.chat;
                    });
                    _messageFocusNode.requestFocus();
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Content Library Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.edit_note,
                  label: 'Drafts',
                  count: mockDrafts,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.schedule,
                  label: 'Scheduled',
                  count: mockScheduled,
                  color: const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.check_circle,
                  label: 'Published',
                  count: mockPublished,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFC107).withOpacity(0.1),
                  const Color(0xFFFF9800).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFC107).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: const Color(0xFFFFC107),
                ),
                const SizedBox(height: 16),
                Text(
                  'Use Chat to Control SEO Agent',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Try saying:\n• "Generate a post about [keyword]"\n• "Schedule 3 posts this week"\n• "Show me draft content"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentView = ViewState.chat;
                    });
                    _messageFocusNode.requestFocus();
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Go to Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentItem(
    BuildContext context, {
    required String title,
    required String status,
    required Color statusColor,
    required String timeAgo,
    required int seoScore,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      timeAgo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Text(
                'SEO',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getScoreColor(seoScore.toDouble()).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getScoreColor(seoScore.toDouble()),
                    width: 2,
                  ),
                ),
                child: Text(
                  seoScore.toString(),
                  style: TextStyle(
                    color: _getScoreColor(seoScore.toDouble()),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentLibrary(Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Mock content data
    final mockContent = [
      {'title': 'Best SEO Tools for 2025', 'status': 'Published', 'color': const Color(0xFF4CAF50), 'date': '2 hours ago', 'score': 85},
      {'title': 'Keyword Research Guide', 'status': 'Scheduled', 'color': const Color(0xFF2196F3), 'date': 'Tomorrow 10:00 AM', 'score': 92},
      {'title': 'Technical SEO Checklist', 'status': 'Draft', 'color': const Color(0xFF9E9E9E), 'date': '1 day ago', 'score': 78},
      {'title': 'Link Building Strategies', 'status': 'Published', 'color': const Color(0xFF4CAF50), 'date': '3 days ago', 'score': 88},
      {'title': 'On-Page SEO Guide', 'status': 'Draft', 'color': const Color(0xFF9E9E9E), 'date': '5 days ago', 'score': 82},
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Content Library',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: true,
                    onSelected: (value) {},
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Drafts'),
                    selected: false,
                    onSelected: (value) {},
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Published'),
                    selected: false,
                    onSelected: (value) {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Content list
          ...mockContent.map((content) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildContentItem(
              context,
              title: content['title'] as String,
              status: content['status'] as String,
              statusColor: content['color'] as Color,
              timeAgo: content['date'] as String,
              seoScore: content['score'] as int,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActivityTab(Project project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Mock activity data
    final mockActivity = [
      {'action': 'Generated', 'title': 'Best SEO Tools for 2025', 'time': '2 hours ago', 'icon': Icons.auto_awesome, 'color': const Color(0xFFFFC107)},
      {'action': 'Published', 'title': 'Keyword Research Guide', 'time': '1 day ago', 'icon': Icons.publish, 'color': const Color(0xFF4CAF50)},
      {'action': 'Scheduled', 'title': 'Technical SEO Checklist', 'time': '2 days ago', 'icon': Icons.schedule, 'color': const Color(0xFF2196F3)},
      {'action': 'Generated', 'title': 'Link Building Strategies', 'time': '3 days ago', 'icon': Icons.auto_awesome, 'color': const Color(0xFFFFC107)},
      {'action': 'Published', 'title': 'On-Page SEO Guide', 'time': '5 days ago', 'icon': Icons.publish, 'color': const Color(0xFF4CAF50)},
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track all SEO Agent actions and content generation history',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          
          // Activity timeline
          ...mockActivity.map((activity) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (activity['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    activity['icon'] as IconData,
                    color: activity['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            activity['action'] as String,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: activity['color'] as Color,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activity['time'] as String,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }



  Color _getScoreColor(double score) => ColorHelpers.getScoreColor(score);
  
  Color _getStatusColor(String? status) => ColorHelpers.getStatusColor(status);
  
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

  Color _getPositionColor(int? position) => ColorHelpers.getPositionColor(position);
  
  void _showCreateProjectDialog() => ProjectDialogs.showCreateProjectDialog(context);

  void _showAddKeywordDialog(BuildContext context, ProjectProvider projectProvider, AuthProvider authProvider) =>
      ProjectDialogs.showAddKeywordDialog(context, projectProvider, authProvider);

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

// Expandable Audit History Item Widget
// _ExpandableAuditHistoryItem extracted to widgets/expandable_audit_item.dart
