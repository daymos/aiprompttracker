import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ConversationList extends StatefulWidget {
  final Function(String) onConversationSelected;

  const ConversationList({
    super.key,
    required this.onConversationSelected,
  });

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  bool _selectionMode = false;
  Set<String> _selectedConversations = {};
  String? _hoveredConversationId;
  
  @override
  void initState() {
    super.initState();
    _loadConversations();
  }
  
  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedConversations.clear();
      }
    });
  }
  
  void _toggleConversationSelection(String conversationId) {
    setState(() {
      if (_selectedConversations.contains(conversationId)) {
        _selectedConversations.remove(conversationId);
        // Exit selection mode if no items are selected
        if (_selectedConversations.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedConversations.add(conversationId);
        // Enter selection mode when first item is selected
        if (!_selectionMode) {
          _selectionMode = true;
        }
      }
    });
  }
  
  void _selectAll() {
    final chatProvider = context.read<ChatProvider>();
    setState(() {
      _selectedConversations = chatProvider.conversations.map((c) => c.id).toSet();
    });
  }

  Future<void> _loadConversations() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();

    try {
      final conversations = await authProvider.apiService.getConversations();
      final conversationList = conversations.map((c) => Conversation(
        id: c['id'],
        title: c['title'],
        createdAt: DateTime.parse(c['created_at']),
        messageCount: c['message_count'],
        projectNames: (c['project_names'] as List<dynamic>?)?.cast<String>() ?? [],
      )).toList();
      
      // Sort by most recent first
      conversationList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      chatProvider.setConversations(conversationList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading conversations: $e')),
        );
      }
    }
  }
  
  Future<void> _renameConversation(String conversationId, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Conversation title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    
    if (newTitle == null || newTitle.isEmpty || newTitle == currentTitle) return;
    
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.apiService.renameConversation(conversationId, newTitle);
      
      // Reload conversations
      await _loadConversations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation renamed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteConversation(String conversationId, String title) async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await authProvider.apiService.deleteConversation(conversationId);
      
      // If deleted conversation was active, clear it
      if (chatProvider.currentConversationId == conversationId) {
        chatProvider.startNewConversation();
      }
      
      // Reload conversations
      await _loadConversations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedConversations() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    
    if (_selectedConversations.isEmpty) return;
    
    final count = _selectedConversations.length;
    
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count conversation${count == 1 ? '' : 's'}?'),
        content: Text(
          count == 1 
            ? 'This conversation will be permanently deleted.'
            : 'These $count conversations will be permanently deleted.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      // Delete each selected conversation
      for (final conversationId in _selectedConversations) {
        await authProvider.apiService.deleteConversation(conversationId);
        
        // If deleted conversation was active, clear it
        if (chatProvider.currentConversationId == conversationId) {
          chatProvider.startNewConversation();
        }
      }
      
      // Exit selection mode and reload
      setState(() {
        _selectionMode = false;
        _selectedConversations.clear();
      });
      
      await _loadConversations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count conversation${count == 1 ? '' : 's'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllConversations() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Conversations'),
        content: const Text('Are you sure you want to delete ALL conversations? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final result = await authProvider.apiService.deleteAllConversations();
      final count = result['count'] ?? 0;
      
      // Clear active conversation
      chatProvider.startNewConversation();
      
      // Reload conversations
      await _loadConversations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count conversation${count == 1 ? '' : 's'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header - changes based on selection mode
          if (!_selectionMode)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text(
                    'Conversations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadConversations,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            )
          else
            Container(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSelectionMode,
                    tooltip: 'Cancel',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedConversations.length} selezionati',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedConversations.length < chatProvider.conversations.length)
                    TextButton(
                      onPressed: _selectAll,
                      child: const Text('Seleziona'),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedConversations.clear();
                        });
                      },
                      child: const Text('Deseleziona'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _selectedConversations.isEmpty ? null : _deleteSelectedConversations,
                    tooltip: 'Delete selected',
                    color: Colors.red[400],
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: chatProvider.conversations.isEmpty
                ? const Center(
                    child: Text('No conversations yet'),
                  )
                : ListView.builder(
                    itemCount: chatProvider.conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = chatProvider.conversations[index];
                      final isSelected = conversation.id == chatProvider.currentConversationId;
                      final isChecked = _selectedConversations.contains(conversation.id);
                      final isHovered = _hoveredConversationId == conversation.id;
                      final showCheckbox = _selectionMode || isHovered;
                      
                      return MouseRegion(
                        onEnter: (_) {
                          setState(() {
                            _hoveredConversationId = conversation.id;
                          });
                        },
                        onExit: (_) {
                          setState(() {
                            _hoveredConversationId = null;
                          });
                        },
                        child: ListTile(
                          // Always reserve space for checkbox with fade animation
                          leading: SizedBox(
                            width: 40,
                            child: AnimatedOpacity(
                              opacity: showCheckbox ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Checkbox(
                                value: isChecked,
                                onChanged: showCheckbox 
                                    ? (_) => _toggleConversationSelection(conversation.id)
                                    : null,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (conversation.projectNames.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                ...conversation.projectNames.map((projectName) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        projectName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            _formatDate(conversation.createdAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: !_selectionMode && isHovered
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_horiz, size: 20),
                                  tooltip: 'More actions',
                                  onSelected: (value) {
                                    if (value == 'rename') {
                                      _renameConversation(conversation.id, conversation.title);
                                    } else if (value == 'delete') {
                                      _deleteConversation(conversation.id, conversation.title);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 12),
                                          Text('Rename'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          SizedBox(width: 12),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                          selected: !_selectionMode && isSelected,
                          onTap: () {
                            if (showCheckbox) {
                              _toggleConversationSelection(conversation.id);
                            } else {
                              widget.onConversationSelected(conversation.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

