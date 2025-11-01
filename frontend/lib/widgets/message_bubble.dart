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

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
  
  // Static method to clear animated messages when starting a new conversation
  static void clearAnimationCache() {
    _MessageBubbleState._animatedMessages.clear();
  }
}

class _MessageBubbleState extends State<MessageBubble> {
  Set<String> addedKeywords = {};
  bool _projectsLoaded = false;
  String _displayedText = '';
  bool _isAnimating = false;
  static final Set<String> _animatedMessages = {};
  
  @override
  void initState() {
    super.initState();
    _loadProjects();
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
    
    // Use a faster speed for better UX (20ms per character)
    const duration = Duration(milliseconds: 20);
    
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
  
  void _downloadTableAsCSV() {
    // Get keyword data from message metadata
    final keywordData = widget.message.messageMetadata?['keyword_data'];
    if (keywordData == null) return;
    
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
  
  String _escapeCsvField(String field) {
    // Escape fields containing commas, quotes, or newlines
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
  
  Future<void> _loadProjects() async {
    if (_projectsLoaded) return;
    
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await projectProvider.loadAllProjects(authProvider.apiService);
    _projectsLoaded = true;
  }
  
  Future<void> _addKeywordToProject(KeywordData keyword) async {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Load projects if not already loaded
    await _loadProjects();
    
    final projects = projectProvider.allProjects;
    
    // No projects - prompt to create
    if (projects.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please create a project first!'),
            action: SnackBarAction(
              label: 'Create',
              onPressed: () {
                Navigator.pushNamed(context, '/project');
              },
            ),
          ),
        );
      }
      return;
    }
    
    // Single project - add directly
    if (projects.length == 1) {
      await _addToSpecificProject(projects[0].id, keyword);
      return;
    }
    
    // Multiple projects - show selector
    if (mounted) {
      final selectedProjectId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: projects.map((project) => ListTile(
              leading: const Icon(Icons.public),
              title: Text(project.name),
              subtitle: Text(project.targetUrl),
              onTap: () => Navigator.pop(context, project.id),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      
      if (selectedProjectId != null) {
        await _addToSpecificProject(selectedProjectId, keyword);
      }
    }
  }
  
  Future<void> _addToSpecificProject(String projectId, KeywordData keyword) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final response = await authProvider.apiService.addKeywordToProject(
        projectId,
        keyword.keyword,
        keyword.searchVolume,
        keyword.competition,
      );
      
      setState(() {
        addedKeywords.add(keyword.keyword);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Added "${keyword.keyword}" to project'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                
                // Show CSV download button if table data is present (only after animation completes)
                if (!isUser && !_isAnimating && widget.message.messageMetadata?['keyword_data'] != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _downloadTableAsCSV,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download as CSV'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                
                // Show "Add to Project" buttons if keywords detected (only after animation completes)
                if (keywords.isNotEmpty && !isUser && !_isAnimating) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: keywords.map((kw) {
                      final isAdded = addedKeywords.contains(kw.keyword);
                      return ElevatedButton.icon(
                        onPressed: isAdded ? null : () => _addKeywordToProject(kw),
                        icon: Icon(isAdded ? Icons.check : Icons.add, size: 16),
                        label: Text(
                          isAdded ? 'Added' : 'Add "${kw.keyword}"',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: isAdded ? Colors.green : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

