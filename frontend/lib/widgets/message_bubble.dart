import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/strategy_provider.dart';
import '../providers/auth_provider.dart';
import '../models/keyword_data.dart';

class MessageBubble extends StatefulWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Set<String> addedKeywords = {};
  
  Future<void> _addKeywordToStrategy(KeywordData keyword) async {
    final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check if user has an active strategy
    if (strategyProvider.activeStrategy == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please create a strategy first!'),
            action: SnackBarAction(label: 'Create', onPressed: null),
          ),
        );
      }
      return;
    }
    
    try {
      await strategyProvider.addKeyword(
        authProvider.apiService,
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
            content: Text('✓ Added "${keyword.keyword}" to strategy'),
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
    final isUser = widget.message.role == 'user';
    final keywords = !isUser ? KeywordData.parseFromMessage(widget.message.content) : <KeywordData>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.smart_toy, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Colors.deepPurple
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isUser
                      ? Text(
                          widget.message.content,
                          style: const TextStyle(color: Colors.white),
                        )
                      : MarkdownBody(
                          data: widget.message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                ),
                
                // Show "Add to Strategy" buttons if keywords detected
                if (keywords.isNotEmpty && !isUser) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: keywords.map((kw) {
                      final isAdded = addedKeywords.contains(kw.keyword);
                      return ElevatedButton.icon(
                        onPressed: isAdded ? null : () => _addKeywordToStrategy(kw),
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
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

