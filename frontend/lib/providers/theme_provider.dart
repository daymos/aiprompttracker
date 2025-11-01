import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  deepPurple,
  ayuMirage,
  nord,
}

class ThemeProvider with ChangeNotifier {
  AppTheme _currentTheme = AppTheme.deepPurple;
  
  AppTheme get currentTheme => _currentTheme;
  
  ThemeProvider() {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme') ?? 0;
    _currentTheme = AppTheme.values[themeIndex];
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
      case AppTheme.deepPurple:
        return _deepPurpleTheme();
      case AppTheme.ayuMirage:
        return _ayuMirageTheme();
      case AppTheme.nord:
        return _nordTheme();
    }
  }
  
  String get themeName {
    switch (_currentTheme) {
      case AppTheme.deepPurple:
        return 'Deep Purple';
      case AppTheme.ayuMirage:
        return 'Ayu Mirage';
      case AppTheme.nord:
        return 'Nord';
    }
  }
  
  // Deep Purple Theme (current)
  ThemeData _deepPurpleTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
  
  // Ayu Mirage Theme (modern vim)
  ThemeData _ayuMirageTheme() {
    const ayuBackground = Color(0xFF1f2430);      // main background
    const ayuSurface = Color(0xFF242936);         // elevated surface
    const ayuSurfaceLight = Color(0xFF2d3544);    // lighter surface
    const ayuForeground = Color(0xFFcbccc6);      // text
    const ayuComment = Color(0xFF5c6773);         // comments
    const ayuOrange = Color(0xFFffd580);          // accent 1
    const ayuBlue = Color(0xFF5ccfe6);            // accent 2
    const ayuPurple = Color(0xFFd4bfff);          // accent 3
    const ayuGreen = Color(0xFFbae67e);           // success
    const ayuRed = Color(0xFFef6b73);             // error
    
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ayuBackground,
      colorScheme: ColorScheme.dark(
        primary: ayuOrange,
        secondary: ayuBlue,
        tertiary: ayuPurple,
        surface: ayuSurface,
        surfaceContainerHighest: ayuSurfaceLight,
        background: ayuBackground,
        error: ayuRed,
        onPrimary: ayuBackground,
        onSecondary: ayuBackground,
        onSurface: ayuForeground,
        onBackground: ayuForeground,
        onError: ayuBackground,
      ).copyWith(
        // Add green for success states
        tertiary: ayuGreen,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ayuForeground),
        bodyLarge: TextStyle(color: ayuForeground),
        bodySmall: TextStyle(color: ayuComment),
      ),
      cardColor: ayuSurface,
      dividerColor: ayuComment,
      useMaterial3: true,
    );
  }
  // Nord Theme (arctic palette)
  ThemeData _nordTheme() {
    const nordBg = Color(0xFF2e3440);             // background
    const nordBgLight = Color(0xFF3b4252);        // lighter bg
    const nordBgLighter = Color(0xFF434c5e);      // even lighter
    const nordFg = Color(0xFFeceff4);             // foreground
    const nordComment = Color(0xFF616e88);        // comment
    const nordFrost1 = Color(0xFF8fbcbb);         // frost cyan
    const nordFrost2 = Color(0xFF88c0d0);         // frost bright cyan
    const nordFrost3 = Color(0xFF81a1c1);         // frost blue
    const nordFrost4 = Color(0xFF5e81ac);         // frost dark blue
    const nordRed = Color(0xFFbf616a);            // red
    const nordOrange = Color(0xFFd08770);         // orange
    const nordYellow = Color(0xFFebcb8b);         // yellow
    const nordGreen = Color(0xFFa3be8c);          // green
    const nordPurple = Color(0xFFb48ead);         // purple
    
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: nordBg,
      colorScheme: ColorScheme.dark(
        primary: nordFrost3,
        secondary: nordFrost2,
        tertiary: nordPurple,
        surface: nordBgLight,
        surfaceContainerHighest: nordBgLighter,
        background: nordBg,
        error: nordRed,
        onPrimary: nordBg,
        onSecondary: nordBg,
        onSurface: nordFg,
        onBackground: nordFg,
        onError: nordBg,
      ).copyWith(
        primaryContainer: nordBgLighter,
        secondaryContainer: nordBgLight,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: nordFg),
        bodyLarge: TextStyle(color: nordFg),
        bodySmall: TextStyle(color: nordComment),
      ),
      cardColor: nordBgLight,
      dividerColor: nordComment,
      useMaterial3: true,
    );
  }
}

