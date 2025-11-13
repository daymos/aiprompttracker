import 'package:flutter/material.dart';
import 'pulsing_button.dart';

/// Quick action suggestion buttons below the chat input
class SuggestionButtons extends StatelessWidget {
  final Function(String) onSuggestionTap;

  const SuggestionButtons({
    super.key,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSuggestionButton(
          context,
          icon: Icons.search,
          label: 'Keywords',
          message: 'I want to research keywords',
        ),
        const SizedBox(width: 8),
        _buildSuggestionButton(
          context,
          icon: Icons.trending_up,
          label: 'Rankings',
          message: 'Check my rankings',
        ),
        const SizedBox(width: 8),
        _buildSuggestionButton(
          context,
          icon: Icons.language,
          label: 'Website',
          message: 'Analyze my website',
        ),
        const SizedBox(width: 8),
        _buildSuggestionButton(
          context,
          icon: Icons.link,
          label: 'Backlinks',
          message: 'Show me backlinks for my website',
        ),
        const SizedBox(width: 8),
        _buildAgenticButton(context),
      ],
    );
  }

  Widget _buildSuggestionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String message,
  }) {
    return Tooltip(
      message: message,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSuggestionTap(message),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgenticButton(BuildContext context) {
    return Tooltip(
      message: 'Let AI create an automated content strategy and generate SEO-optimized posts',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSuggestionTap(
            'I want to use Agentic SEO mode to create an automated content strategy and generate blog posts for my website',
          ),
          borderRadius: BorderRadius.circular(12),
          child: PulsingButton(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Agentic SEO',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

