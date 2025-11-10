import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../models/keyword_data.dart';
import 'dart:html' as html;
import 'dart:convert';

class MessageBubble extends StatefulWidget {
  final Message message;
  final String? projectId; // Optional project ID for pinning

  const MessageBubble({super.key, required this.message, this.projectId});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
  
  // Static method to clear animated messages when starting a new conversation
  static void clearAnimationCache() {
    _MessageBubbleState._animatedMessages.clear();
  }
}

class _MessageBubbleState extends State<MessageBubble> {
  String _displayedText = '';
  bool _isAnimating = false;
  String? _pinnedItemId; // Track the pin ID for this message
  String? _pinnedProjectId; // Track the project ID this message is pinned to
  static final Set<String> _animatedMessages = {};
  
  @override
  void initState() {
    super.initState();
    _startTextAnimation();
  }
  
  void _startTextAnimation() {
    // Only animate assistant messages
    if (widget.message.role != 'assistant') {
      setState(() {
        _displayedText = widget.message.content;
      });
      return;
    }
    
    // Don't re-animate messages we've already shown
    if (_animatedMessages.contains(widget.message.id)) {
      setState(() {
        _displayedText = widget.message.content;
        _isAnimating = false;
      });
      return;
    }
    
    // Don't animate historical messages (older than 5 seconds)
    final messageAge = DateTime.now().difference(widget.message.createdAt);
    if (messageAge.inSeconds > 5) {
      setState(() {
        _displayedText = widget.message.content;
        _isAnimating = false;
      });
      return;
    }
    
    // Mark this message as animated
    _animatedMessages.add(widget.message.id);
    
    // Animate text character by character
    _isAnimating = true;
    final fullText = widget.message.content;
    int currentIndex = 0;
    
    // Use a faster speed for better UX (14ms per character, 30% faster)
    const duration = Duration(milliseconds: 14);
    
    void animateNext() {
      if (!mounted || currentIndex >= fullText.length) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
            _displayedText = fullText;
          });
        }
        return;
      }
      
      setState(() {
        currentIndex++;
        _displayedText = fullText.substring(0, currentIndex);
      });
      
      Future.delayed(duration, animateNext);
    }
    
    animateNext();
  }
  
  void _openDataPanel() {
    final metadata = widget.message.messageMetadata;
    if (metadata == null) return;

    final chatProvider = context.read<ChatProvider>();
    
    // Check for keyword data
    if (metadata['keyword_data'] != null) {
      chatProvider.openDataPanel(
        data: List<Map<String, dynamic>>.from(metadata['keyword_data']),
        title: 'Keyword Research Results',
      );
      return;
    }
    
    // Check for ranking data
    if (metadata['ranking_data'] != null) {
      final domain = metadata['domain'] ?? 'Unknown Domain';
      chatProvider.openDataPanel(
        data: List<Map<String, dynamic>>.from(metadata['ranking_data']),
        title: 'Ranking Report - $domain',
      );
      return;
    }
    
    // Check for technical SEO issues
    if (metadata['technical_seo_issues'] != null) {
      final url = metadata['url'] ?? 'Website';
      chatProvider.openDataPanel(
        data: List<Map<String, dynamic>>.from(metadata['technical_seo_issues']),
        title: 'Technical SEO Issues - $url',
      );
      return;
    }
  }

  void _downloadTableAsCSV() {
    final metadata = widget.message.messageMetadata;
    if (metadata == null) return;
    
    // Check for keyword data
    final keywordData = metadata['keyword_data'];
    if (keywordData != null) {
      _downloadKeywordCSV(keywordData);
      return;
    }
    
    // Check for ranking data
    final rankingData = metadata['ranking_data'];
    if (rankingData != null) {
      _downloadRankingCSV(rankingData, metadata['domain'] ?? 'unknown');
      return;
    }
    
    // Check for technical SEO issues
    final technicalSeoIssues = metadata['technical_seo_issues'];
    if (technicalSeoIssues != null) {
      _downloadTechnicalSeoCSV(technicalSeoIssues, metadata['url'] ?? 'unknown');
      return;
    }
  }

  void _downloadKeywordCSV(dynamic keywordData) {
    
    // Convert to CSV
    final csvContent = StringBuffer();
    
    // Header row
    csvContent.writeln('Keyword,Avg. Monthly Searches,Competition,CPC,SERP Reality');
    
    // Data rows
    for (final item in keywordData) {
      final keyword = item['keyword'] ?? '';
      final volume = item['search_volume'] ?? '';
      final competition = item['competition'] ?? '';
      final cpc = item['cpc'] ?? '';
      final serpInsight = item['serp_insight'] ?? '';
      
      // Escape commas and quotes in CSV
      final escapedKeyword = _escapeCsvField(keyword.toString());
      final escapedSerpInsight = _escapeCsvField(serpInsight.toString());
      
      csvContent.writeln('$escapedKeyword,$volume,$competition,$cpc,$escapedSerpInsight');
    }
    
    // Create blob and download
    final bytes = utf8.encode(csvContent.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = 'keyword_data_${DateTime.now().millisecondsSinceEpoch}.csv';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV downloaded successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  void _downloadRankingCSV(dynamic rankingData, String domain) {
    // Convert to CSV
    final csvContent = StringBuffer();
    
    // Header row
    csvContent.writeln('Keyword,Position,Ranking URL,Page Title');
    
    // Data rows
    for (final item in rankingData) {
      final keyword = item['keyword'] ?? '';
      final position = item['position']?.toString() ?? 'Not ranking';
      final url = item['url'] ?? '';
      final title = item['title'] ?? '';
      
      // Escape commas and quotes in CSV
      final escapedKeyword = _escapeCsvField(keyword.toString());
      final escapedUrl = _escapeCsvField(url.toString());
      final escapedTitle = _escapeCsvField(title.toString());
      
      csvContent.writeln('$escapedKeyword,$position,$escapedUrl,$escapedTitle');
    }
    
    // Create and download the file
    final bytes = utf8.encode(csvContent.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = 'ranking_report_${domain}_${DateTime.now().millisecondsSinceEpoch}.csv';
    html.document.body?.children.add(anchor);
    
    anchor.click();
    
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ranking report downloaded successfully')),
      );
    }
  }

  void _downloadTechnicalSeoCSV(dynamic technicalSeoIssues, String url) {
    // Convert to CSV
    final csvContent = StringBuffer();
    
    // Header row
    csvContent.writeln('Severity,Issue Type,Page,Element,Description,How to Fix');
    
    // Data rows
    for (final item in technicalSeoIssues) {
      final severity = item['severity'] ?? '';
      final type = item['type'] ?? '';
      final page = item['page'] ?? '';
      final element = item['element'] ?? '';
      final description = item['description'] ?? '';
      final recommendation = item['recommendation'] ?? '';
      
      // Escape commas and quotes in CSV
      final escapedSeverity = _escapeCsvField(severity.toString());
      final escapedType = _escapeCsvField(type.toString());
      final escapedPage = _escapeCsvField(page.toString());
      final escapedElement = _escapeCsvField(element.toString());
      final escapedDescription = _escapeCsvField(description.toString());
      final escapedRecommendation = _escapeCsvField(recommendation.toString());
      
      csvContent.writeln('$escapedSeverity,$escapedType,$escapedPage,$escapedElement,$escapedDescription,$escapedRecommendation');
    }
    
    // Create and download the file
    final bytes = utf8.encode(csvContent.toString());
    final blob = html.Blob([bytes]);
    final csvUrl = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = csvUrl
      ..style.display = 'none'
      ..download = 'technical_seo_audit_${url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
    html.document.body?.children.add(anchor);
    
    anchor.click();
    
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(csvUrl);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Technical SEO audit downloaded successfully')),
      );
    }
  }

  String _escapeCsvField(String field) {
    // Escape fields containing commas, quotes, or newlines
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
  
  Future<void> _createProjectAndPin() async {
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

        // Pin the message to the new project
        await _pinMessageToProject(newProjectId);
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

  Future<void> _pinMessageToProject(String projectId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      // Let the backend generate an AI summary for the title
      final pinResponse = await authProvider.apiService.pinItem(
        projectId: projectId,
        contentType: 'message',
        title: 'Message', // Backend will replace with AI-generated summary
        content: widget.message.content,
        sourceMessageId: widget.message.id,
        sourceConversationId: chatProvider.currentConversationId,
      );

      // Update state to show pinned status
      if (mounted) {
        setState(() {
          _pinnedItemId = pinResponse['id'];
          _pinnedProjectId = pinResponse['project_id'];
        });

        // Find project name for the snackbar
        final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
        final project = projectProvider.allProjects.firstWhere(
          (p) => p.id == projectId,
          orElse: () => throw Exception('Project not found'),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Response pinned to "${project.name}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pinning: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isUser = widget.message.role == 'user';
    final keywords = !isUser ? KeywordData.parseFromMessage(widget.message.content) : <KeywordData>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar on the left ONLY for user messages (Claude style)
          if (isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.grey[800],
              radius: 18,
              child: Text(
                (authProvider.name?.substring(0, 1) ?? authProvider.email?.substring(0, 1) ?? 'U').toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: isUser ? const EdgeInsets.all(12) : EdgeInsets.zero,
                  decoration: isUser
                      ? BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: isUser
                      ? Text(
                          widget.message.content,
                          style: const TextStyle(color: Colors.white),
                        )
                      : MarkdownBody(
                          data: _displayedText,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                ),
                
                // Show data action buttons if table data is present (only after animation completes)
                if (!isUser && !_isAnimating && (
                    widget.message.messageMetadata?['keyword_data'] != null ||
                    widget.message.messageMetadata?['ranking_data'] != null ||
                    widget.message.messageMetadata?['technical_seo_issues'] != null
                )) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _openDataPanel,
                        icon: const Icon(Icons.table_chart, size: 16),
                        label: const Text('View Data Table'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _downloadTableAsCSV,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download CSV'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],

                // Show pin button for assistant messages (only after animation completes)
                if (!isUser && !_isAnimating) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _pinnedItemId != null
                      ? _buildPinnedButton()
                      : _buildPinButton(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unpinMessage() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.apiService.unpinItem(_pinnedItemId!);

      if (mounted) {
        setState(() {
          _pinnedItemId = null;
          _pinnedProjectId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Response unpinned'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unpinning: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changePinProject(String newProjectId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // First unpin from current project
      await authProvider.apiService.unpinItem(_pinnedItemId!);

      // Then pin to new project
      final pinResponse = await authProvider.apiService.pinItem(
        projectId: newProjectId,
        contentType: 'message',
        title: widget.message.content.length > 50
            ? '${widget.message.content.substring(0, 47)}...'
            : widget.message.content,
        content: widget.message.content,
        sourceMessageId: widget.message.id,
        sourceConversationId: Provider.of<ChatProvider>(context, listen: false).currentConversationId,
      );

      if (mounted) {
        setState(() {
          _pinnedItemId = pinResponse['id'];
          _pinnedProjectId = pinResponse['project_id'];
        });

        // Find new project name for snackbar
        final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
        final newProject = projectProvider.allProjects.firstWhere(
          (p) => p.id == newProjectId,
          orElse: () => throw Exception('Project not found'),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Response moved to "${newProject.name}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing pin: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPinButton() {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'new_project') {
          await _createProjectAndPin();
        } else {
          await _pinMessageToProject(value);
        }
      },
      itemBuilder: (BuildContext context) {
        final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
        final items = projectProvider.allProjects.map((project) {
          return PopupMenuItem<String>(
            value: project.id,
            height: 32, // Make menu items more compact
            child: Text(
              project.name,
              style: const TextStyle(fontSize: 14), // Smaller font
            ),
          );
        }).toList();
        
        // Add separator and "Create new project" option
        if (items.isNotEmpty) {
          items.add(
            const PopupMenuItem<String>(
              value: 'separator',
              enabled: false,
              height: 8,
              child: Divider(),
            ),
          );
        }
        
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
        
        return items;
      },
      child: TextButton(
        onPressed: null, // Handled by PopupMenuButton
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.push_pin, size: 16),
            const SizedBox(width: 4),
            const Text('Pin to project'),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildPinnedButton() {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final project = projectProvider.allProjects.firstWhere(
      (p) => p.id == _pinnedProjectId,
      orElse: () => throw Exception('Project not found'),
    );

    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'unpin') {
          await _unpinMessage();
        } else {
          await _changePinProject(value);
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          // Option to pin to a different project
          ...projectProvider.allProjects.where((p) => p.id != _pinnedProjectId).map((project) {
            return PopupMenuItem<String>(
              value: project.id,
              height: 32,
              child: Text(
                'Move to ${project.name}',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }),
          // Separator
          const PopupMenuItem<String>(
            value: 'separator',
            enabled: false,
            height: 8,
            child: Divider(),
          ),
          // Option to unpin
          const PopupMenuItem<String>(
            value: 'unpin',
            height: 32,
            child: Text(
              'Unpin',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          ),
        ];
      },
      child: TextButton.icon(
        onPressed: null, // Handled by PopupMenuButton
        icon: const Icon(Icons.push_pin, size: 16),
        label: Text(
          'Pinned to ${project.name}',
          style: const TextStyle(fontSize: 12),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

