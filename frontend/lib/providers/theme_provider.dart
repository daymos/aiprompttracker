import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  paperColorLight,
  paperColorDark,
}

class ThemeProvider with ChangeNotifier {
  AppTheme _currentTheme = AppTheme.paperColorDark;
  
  AppTheme get currentTheme => _currentTheme;
  
  ThemeProvider() {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme') ?? 1; // Default to dark theme
    // Safety check for old saved preferences
    if (themeIndex >= AppTheme.values.length) {
      _currentTheme = AppTheme.paperColorDark;
    } else {
      _currentTheme = AppTheme.values[themeIndex];
    }
    notifyListeners();
  }
  
  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', theme.index);
    notifyListeners();
  }
  
  ThemeData get themeData {
    switch (_currentTheme) {
      case AppTheme.paperColorLight:
        return _paperColorLightTheme();
      case AppTheme.paperColorDark:
        return _paperColorDarkTheme();
    }
  }
  
  String get themeName {
    switch (_currentTheme) {
      case AppTheme.paperColorLight:
        return 'PaperColor Light';
      case AppTheme.paperColorDark:
        return 'PaperColor Dark';
    }
  }
  
  // PaperColor Light Theme (inspired by Google Material Design)
  ThemeData _paperColorLightTheme() {
    const paperBg = Color(0xFFeeeeee);               // light gray background
    const paperBgAlt = Color(0xFFffffff);            // white surfaces
    const paperBg2 = Color(0xFFe4e4e4);              // darker gray for elevation
    const paperFg = Color(0xFF444444);               // dark text
    const paperFg2 = Color(0xFF005f87);              // darker blue-gray text
    const paperComment = Color(0xFF808080);          // gray comment
    const paperBlue = Color(0xFF005f87);             // blue
    const paperBrightBlue = Color(0xFF0087af);       // bright blue
    const paperCyan = Color(0xFF00afaf);             // cyan
    const paperGreen = Color(0xFF008700);            // green
    const paperYellow = Color(0xFFd75f00);           // orange-yellow
    const paperOrange = Color(0xFFd70000);           // orange-red
    const paperRed = Color(0xFFd70087);              // red-pink
    const paperPurple = Color(0xFF8700af);           // purple
    const paperPink = Color(0xFFd75f87);             // pink
    
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: paperBg,
      colorScheme: ColorScheme.light(
        primary: paperBlue,
        secondary: paperCyan,
        tertiary: paperPurple,
        surface: paperBgAlt,
        surfaceContainerHighest: paperBg2,
        background: paperBg,
        error: paperOrange,
        onPrimary: paperBgAlt,
        onSecondary: paperBgAlt,
        onSurface: paperFg,
        onBackground: paperFg,
        onError: paperBgAlt,
      ).copyWith(
        primaryContainer: paperBg2,
        secondaryContainer: paperBgAlt,
        outline: paperComment,
        // Yellow accent for key features
        tertiary: const Color(0xFFd75f00),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: paperFg),
        bodyLarge: TextStyle(color: paperFg2),
        bodySmall: TextStyle(color: paperComment),
      ),
      cardColor: paperBgAlt,
      dividerColor: paperComment,
      iconTheme: const IconThemeData(color: paperFg),
      appBarTheme: const AppBarTheme(
        backgroundColor: paperBgAlt,
        foregroundColor: paperFg,
        elevation: 1,
      ),
      useMaterial3: true,
    );
  }
  
  // PaperColor Dark Theme (inspired by Google Material Design)
  ThemeData _paperColorDarkTheme() {
    const paperBgDark = Color(0xFF1c1c1c);           // dark background
    const paperBgDark2 = Color(0xFF262626);          // slightly lighter
    const paperBgDark3 = Color(0xFF303030);          // elevated surface
    const paperFgDark = Color(0xFFd0d0d0);           // light text
    const paperFg2Dark = Color(0xFFe4e4e4);          // brighter text
    const paperCommentDark = Color(0xFF585858);      // gray comment
    const paperBlueDark = Color(0xFF00afaf);         // bright cyan-blue
    const paperCyanDark = Color(0xFF00d7d7);         // bright cyan
    const paperGreenDark = Color(0xFF5faf00);        // green
    const paperYellowDark = Color(0xFFd7af5f);       // yellow
    const paperOrangeDark = Color(0xFFff5f00);       // orange
    const paperRedDark = Color(0xFFd70000);          // red
    const paperPurpleDark = Color(0xFFaf87d7);       // purple
    const paperPinkDark = Color(0xFFff5faf);         // pink
    
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: paperBgDark,
      colorScheme: ColorScheme.dark(
        primary: paperBlueDark,
        secondary: paperCyanDark,
        tertiary: paperPurpleDark,
        surface: paperBgDark2,
        surfaceContainerHighest: paperBgDark3,
        background: paperBgDark,
        error: paperOrangeDark,
        onPrimary: paperBgDark,
        onSecondary: paperBgDark,
        onSurface: paperFgDark,
        onBackground: paperFgDark,
        onError: paperBgDark,
      ).copyWith(
        primaryContainer: paperBgDark3,
        secondaryContainer: paperBgDark2,
        outline: paperCommentDark,
        // Yellow accent for key features
        tertiary: paperYellowDark,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: paperFgDark),
        bodyLarge: TextStyle(color: paperFg2Dark),
        bodySmall: TextStyle(color: paperCommentDark),
      ),
      cardColor: paperBgDark2,
      dividerColor: paperCommentDark,
      iconTheme: const IconThemeData(color: paperFgDark),
      appBarTheme: const AppBarTheme(
        backgroundColor: paperBgDark2,
        foregroundColor: paperFgDark,
        elevation: 1,
      ),
      useMaterial3: true,
    );
  }
}

