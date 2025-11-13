import 'package:flutter/material.dart';

/// Small chip widget showing competition level (LOW/MEDIUM/HIGH)
class CompetitionChip extends StatelessWidget {
  final String competition;

  const CompetitionChip({
    super.key,
    required this.competition,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (competition.toUpperCase()) {
      case 'LOW':
        color = Colors.green;
        break;
      case 'MEDIUM':
        color = Colors.orange;
        break;
      case 'HIGH':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        competition.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

