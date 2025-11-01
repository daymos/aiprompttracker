import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/project_provider.dart';
import '../providers/auth_provider.dart';
import '../models/keyword_data.dart';

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

