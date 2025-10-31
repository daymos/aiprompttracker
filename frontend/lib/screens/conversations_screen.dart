import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/conversation_list.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
      ),
      body: ConversationList(
        onConversationSelected: (conversationId) async {
          final chatProvider = context.read<ChatProvider>();
          final authProvider = context.read<AuthProvider>();
          
          chatProvider.setLoading(true);
          
          try {
            final conversationData = await authProvider.apiService.getConversation(conversationId);
            
            // Load messages
            final messages = (conversationData['messages'] as List).map((m) => Message(
              id: m['id'],
              role: m['role'],
              content: m['content'],
              createdAt: DateTime.parse(m['created_at']),
            )).toList();
            
            chatProvider.setCurrentConversation(conversationId);
            chatProvider.setMessages(messages);
            
            // Navigate back to chat
            if (context.mounted) {
              Navigator.pop(context);
            }
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
    );
  }
}

