import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/conversation_list.dart';

/// View for displaying and managing conversation history
class ConversationsView extends StatelessWidget {
  final VoidCallback onSwitchToChatView;

  const ConversationsView({
    super.key,
    required this.onSwitchToChatView,
  });

  @override
  Widget build(BuildContext context) {
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
                    onSwitchToChatView();
                  } catch (e) {
                    if (context.mounted) {
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
}

