import 'package:flutter/material.dart';

/// Small helper widget that shows a tip with an arrow icon
class QuickTip extends StatelessWidget {
  final String title;
  final String? command;

  const QuickTip({
    super.key,
    required this.title,
    this.command,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.arrow_right, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 13, color: Colors.grey[300]),
            ),
          ),
        ],
      ),
    );
  }
}

