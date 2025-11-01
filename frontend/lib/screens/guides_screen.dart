import 'package:flutter/material.dart';

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How It Works'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'How Keywords.chat Works',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI-powered SEO assistant for keyword research and website optimization',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 32),
              
              _buildFeatureSection(
                context,
                Icons.chat_bubble_outline,
                'Chat Interface',
                'Simply chat with our AI assistant about your SEO needs. Ask questions, request analysis, and get actionable advice in real-time.',
              ),
              
              _buildFeatureSection(
                context,
                Icons.search,
                'Keyword Research',
                'Tell the AI about your niche or website, and it will research relevant keywords with real search volume data, competition levels, and CPC information.',
              ),
              
              _buildFeatureSection(
                context,
                Icons.language,
                'Website Analysis',
                'Provide any URL and the AI will automatically fetch and analyze the website content, including titles, meta descriptions, headings, and main content to suggest optimization opportunities.',
              ),
              
              _buildFeatureSection(
                context,
                Icons.track_changes,
                'Keyword Tracking',
                'Create projects to track your website\'s rankings for specific keywords. Monitor your position on Google and get updates when rankings change.',
              ),
              
              _buildFeatureSection(
                context,
                Icons.auto_awesome,
                'Two Modes',
                'Choose between "Ask" mode (direct commands) or "Agent" mode (guided workflow) depending on whether you want quick answers or step-by-step assistance.',
              ),
              
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Getting Started',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTip('1. Start a new conversation from the sidebar'),
                    const SizedBox(height: 8),
                    _buildTip('2. Tell the AI about your website or niche'),
                    const SizedBox(height: 8),
                    _buildTip('3. Ask for keyword research, website analysis, or ranking checks'),
                    const SizedBox(height: 8),
                    _buildTip('4. Review the suggestions and create a project to track keywords'),
                    const SizedBox(height: 8),
                    _buildTip('5. Monitor your progress from the Projects section'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureSection(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}

