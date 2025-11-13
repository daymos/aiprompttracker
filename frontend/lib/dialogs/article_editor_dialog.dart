import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Full-screen article editor with markdown support and live preview
/// Platform-agnostic design that works with WordPress now, other CMSs later
class ArticleEditorDialog extends StatefulWidget {
  final String? articleId; // null = new article
  final String projectId;
  final String cmsType; // 'wordpress', 'ghost', etc.

  const ArticleEditorDialog({
    super.key,
    this.articleId,
    required this.projectId,
    this.cmsType = 'wordpress',
  });

  @override
  State<ArticleEditorDialog> createState() => _ArticleEditorDialogState();
}

class _ArticleEditorDialogState extends State<ArticleEditorDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _excerptController = TextEditingController();
  
  bool _loading = true;
  bool _saving = false;
  bool _showPreview = true;
  String _currentStatus = 'draft';
  
  // SEO data
  List<String> _keywords = [];
  int? _seoScore;
  int _wordCount = 0;
  
  // WordPress-specific
  List<String> _selectedCategories = [];
  List<String> _tags = [];
  List<dynamic> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _loadArticle();
    _contentController.addListener(_updateWordCount);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _excerptController.dispose();
    _contentController.removeListener(_updateWordCount);
    super.dispose();
  }

  void _updateWordCount() {
    final text = _contentController.text;
    final words = text.trim().split(RegExp(r'\s+'));
    setState(() {
      _wordCount = text.isEmpty ? 0 : words.length;
    });
  }

  Future<void> _loadArticle() async {
    if (widget.articleId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final response = await authProvider.apiService.getGeneratedContent(
        widget.projectId,
        widget.articleId!,
      );

      if (response['success']) {
        final article = response['content'];
        setState(() {
          _titleController.text = article['title'] ?? '';
          _contentController.text = article['content'] ?? '';
          _excerptController.text = article['excerpt'] ?? '';
          _currentStatus = article['status'] ?? 'draft';
          _keywords = List<String>.from(article['target_keywords'] ?? []);
          _seoScore = article['seo_score'];
          _selectedCategories = List<String>.from(article['metadata']?['categories'] ?? []);
          _tags = List<String>.from(article['metadata']?['tags'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading article: $e')),
        );
      }
      setState(() => _loading = false);
    }

    // Load WordPress categories
    if (widget.cmsType == 'wordpress') {
      _loadWordPressCategories();
    }
  }

  Future<void> _loadWordPressCategories() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final response = await authProvider.apiService.getCMSCategories(widget.projectId);
      
      if (response['success']) {
        setState(() {
          _availableCategories = response['categories'] ?? [];
        });
      }
    } catch (e) {
      // Categories optional
    }
  }

  Future<void> _saveArticle({bool publish = false}) async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final response = await authProvider.apiService.saveGeneratedContent(
        projectId: widget.projectId,
        articleId: widget.articleId,
        title: _titleController.text,
        content: _contentController.text,
        excerpt: _excerptController.text,
        keywords: _keywords,
        status: publish ? 'published' : 'draft',
        metadata: {
          'categories': _selectedCategories,
          'tags': _tags,
        },
      );

      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(publish ? 'Published successfully!' : 'Saved as draft')),
          );
          Navigator.of(context).pop(true); // Return true to indicate refresh needed
        }
      } else {
        throw Exception(response['error'] ?? 'Save failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        appBar: AppBar(
          title: Text(widget.articleId == null ? 'New Article' : 'Edit Article'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // Preview toggle
            IconButton(
              icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPreview = !_showPreview),
              tooltip: _showPreview ? 'Hide preview' : 'Show preview',
            ),
            const SizedBox(width: 8),
            // Save as draft
            TextButton.icon(
              onPressed: _saving ? null : () => _saveArticle(publish: false),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Draft'),
            ),
            const SizedBox(width: 8),
            // Publish button
            FilledButton.icon(
              onPressed: _saving ? null : () => _saveArticle(publish: true),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish),
              label: Text(_currentStatus == 'published' ? 'Update' : 'Publish'),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Main editor area
                  Expanded(
                    child: Row(
                      children: [
                        // Editor pane
                        Expanded(
                          flex: _showPreview ? 1 : 2,
                          child: _buildEditorPane(isDark),
                        ),
                        // Preview pane
                        if (_showPreview)
                          Container(
                            width: 1,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                          ),
                        if (_showPreview)
                          Expanded(
                            flex: 1,
                            child: _buildPreviewPane(isDark),
                          ),
                      ],
                    ),
                  ),
                  // Bottom metadata/publish panel
                  _buildBottomPanel(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildEditorPane(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title input
          TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              hintText: 'Article title...',
              border: InputBorder.none,
            ),
            maxLines: null,
          ),
          const SizedBox(height: 24),
          // Content input (markdown)
          TextField(
            controller: _contentController,
            style: const TextStyle(fontSize: 16, height: 1.6),
            decoration: const InputDecoration(
              hintText: 'Write your article in Markdown...\n\n# Heading\n\n**Bold text**\n\n- List item',
              border: InputBorder.none,
            ),
            maxLines: null,
            minLines: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPane(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview header
            Row(
              children: [
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'PREVIEW',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Preview content
            if (_titleController.text.isNotEmpty) ...[
              Text(
                _titleController.text,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Markdown preview
            MarkdownBody(
              data: _contentController.text.isEmpty
                  ? '_No content yet..._'
                  : _contentController.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 16, height: 1.6),
                h1: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                h2: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                blockquotePadding: const EdgeInsets.all(16),
                blockquoteDecoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: Theme.of(context).primaryColor, width: 4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // SEO Stats
          _buildStatChip(
            icon: Icons.text_fields,
            label: 'Words',
            value: _wordCount.toString(),
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          if (_seoScore != null)
            _buildStatChip(
              icon: Icons.speed,
              label: 'SEO Score',
              value: _seoScore.toString(),
              isDark: isDark,
              color: _seoScore! >= 80
                  ? Colors.green
                  : _seoScore! >= 60
                      ? Colors.orange
                      : Colors.red,
            ),
          const SizedBox(width: 12),
          if (_keywords.isNotEmpty)
            _buildStatChip(
              icon: Icons.key,
              label: 'Keywords',
              value: _keywords.length.toString(),
              isDark: isDark,
            ),
          const Spacer(),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _currentStatus == 'published'
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _currentStatus == 'published'
                    ? Colors.green
                    : Colors.grey,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentStatus == 'published'
                      ? Icons.check_circle
                      : Icons.edit_note,
                  size: 16,
                  color: _currentStatus == 'published'
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _currentStatus == 'published'
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (color ?? Colors.grey).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? (isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

