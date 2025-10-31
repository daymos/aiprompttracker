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
  bool _strategiesLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _loadStrategies();
  }
  
  Future<void> _loadStrategies() async {
    if (_strategiesLoaded) return;
    
    final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await strategyProvider.loadAllStrategies(authProvider.apiService);
    _strategiesLoaded = true;
  }
  
  Future<void> _addKeywordToStrategy(KeywordData keyword) async {
    final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Load strategies if not already loaded
    await _loadStrategies();
    
    final strategies = strategyProvider.allStrategies;
    
    // No strategies - prompt to create
    if (strategies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please create a strategy first!'),
            action: SnackBarAction(
              label: 'Create',
              onPressed: () {
                Navigator.pushNamed(context, '/strategy');
              },
            ),
          ),
        );
      }
      return;
    }
    
    // Single strategy - add directly
    if (strategies.length == 1) {
      await _addToSpecificStrategy(strategies[0].id, keyword);
      return;
    }
    
    // Multiple strategies - show selector
    if (mounted) {
      final selectedStrategyId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Strategy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: strategies.map((strategy) => ListTile(
              leading: Icon(
                strategy.isActive ? Icons.star : Icons.public,
                color: strategy.isActive ? Colors.amber : null,
              ),
              title: Text(strategy.name),
              subtitle: Text(strategy.targetUrl),
              onTap: () => Navigator.pop(context, strategy.id),
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
      
      if (selectedStrategyId != null) {
        await _addToSpecificStrategy(selectedStrategyId, keyword);
      }
    }
  }
  
  Future<void> _addToSpecificStrategy(String strategyId, KeywordData keyword) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final response = await authProvider.apiService.addKeywordToStrategy(
        strategyId,
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

