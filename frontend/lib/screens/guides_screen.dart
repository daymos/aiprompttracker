import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guides'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Start a Guided Conversation',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildGuideCard(
            context,
            'What can Keywords.chat do?',
            'Learn about all features and capabilities',
            'What can keywords.chat do for me? I\'d like to understand all the features and how you can help with my SEO.',
            Icons.info_outline,
          ),
          const SizedBox(height: 12),
          _buildGuideCard(
            context,
            'Track keywords',
            'Set up keyword tracking and monitoring',
            'I want to track keywords for my website. Can you help me set up keyword tracking and monitoring?',
            Icons.track_changes,
          ),
          const SizedBox(height: 12),
          _buildGuideCard(
            context,
            'Analyze my website',
            'Get SEO opportunities for your site',
            'I want to analyze my website for SEO opportunities. Can you help me understand what keywords I should target?',
            Icons.search,
          ),
          const SizedBox(height: 12),
          _buildGuideCard(
            context,
            'Find keyword ideas',
            'Discover keywords for your niche',
            'I need help finding keyword ideas for my niche. What should I be ranking for?',
            Icons.lightbulb_outline,
          ),
          const SizedBox(height: 12),
          _buildGuideCard(
            context,
            'Understand keyword difficulty',
            'Learn about ranking difficulty',
            'Can you explain keyword difficulty and help me find keywords I can actually rank for?',
            Icons.analytics_outlined,
          ),
          const SizedBox(height: 12),
          _buildGuideCard(
            context,
            'Create an SEO strategy',
            'Build a keyword strategy',
            'I\'m new to SEO. Can you help me create a keyword strategy for my website?',
            Icons.map_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(
    BuildContext context,
    String title,
    String description,
    String prompt,
    IconData icon,
  ) {
    return Card(
      child: InkWell(
        onTap: () async {
          final chatProvider = context.read<ChatProvider>();
          final authProvider = context.read<AuthProvider>();
          
          // Start new conversation
          chatProvider.startNewConversation();
          
          // Navigate back to chat
          Navigator.pop(context);
          
          // Send the message after a brief delay to ensure the UI is ready
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Add user message
          chatProvider.addMessage(Message(
            id: DateTime.now().toString(),
            role: 'user',
            content: prompt,
            createdAt: DateTime.now(),
          ));
          
          chatProvider.setLoading(true);
          
          try {
            final response = await authProvider.apiService.sendMessage(
              prompt,
              chatProvider.currentConversationId,
            );
            
            chatProvider.setCurrentConversation(response['conversation_id']);
            chatProvider.addMessage(Message(
              id: DateTime.now().toString(),
              role: 'assistant',
              content: response['message'],
              createdAt: DateTime.now(),
            ));
          } catch (e) {
            // Error will be shown in chat screen
            print('Error sending guided message: $e');
          } finally {
            chatProvider.setLoading(false);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

