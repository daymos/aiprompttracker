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
  @override
  void initState() {
    super.initState();
    _loadConversations();
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
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: _deleteAllConversations,
                  tooltip: 'Delete all conversations',
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
                      
                      return ListTile(
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
                        selected: isSelected,
                        onTap: () {
                          widget.onConversationSelected(conversation.id);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteConversation(
                            conversation.id,
                            conversation.title,
                          ),
                          tooltip: 'Delete conversation',
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

