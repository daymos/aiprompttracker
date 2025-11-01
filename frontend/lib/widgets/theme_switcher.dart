import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    
    return PopupMenuButton<AppTheme>(
      icon: Icon(
        Icons.palette_outlined,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      tooltip: 'Change theme',
      onSelected: (AppTheme theme) {
        themeProvider.setTheme(theme);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppTheme>>[
        _buildThemeMenuItem(
          context,
          AppTheme.deepPurple,
          'Deep Purple',
          '🟣',
          themeProvider.currentTheme == AppTheme.deepPurple,
        ),
        const PopupMenuDivider(),
        _buildThemeMenuItem(
          context,
          AppTheme.ayuMirage,
          'Ayu Mirage',
          '🌙',
          themeProvider.currentTheme == AppTheme.ayuMirage,
        ),
        const PopupMenuDivider(),
        _buildThemeMenuItem(
          context,
          AppTheme.nord,
          'Nord',
          '❄️',
          themeProvider.currentTheme == AppTheme.nord,
        ),
      ],
    );
  }
  
  PopupMenuItem<AppTheme> _buildThemeMenuItem(
    BuildContext context,
    AppTheme theme,
    String name,
    String emoji,
    bool isSelected,
  ) {
    return PopupMenuItem<AppTheme>(
      value: theme,
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

