import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  // Light mode gradient colors (purple theme)
  List<Color> get lightGradient => const [
        Color(0xFF4C1D95),
        Color(0xFF5B21B6),
        Color(0xFF93C5FD),
      ];

  // Dark mode gradient colors
  List<Color> get darkGradient => const [
        Color(0xFF1A1A2E),
        Color(0xFF16213E),
        Color(0xFF0F0F23),
      ];

  // Get current gradient based on mode
  List<Color> get currentGradient => _isDarkMode ? darkGradient : lightGradient;

  // Glass container color
  Color get glassColor => _isDarkMode
      ? Colors.white.withOpacity(0.08)
      : Colors.white.withOpacity(0.12);

  // Glass border color
  Color get glassBorderColor => _isDarkMode
      ? Colors.white.withOpacity(0.15)
      : Colors.white.withOpacity(0.25);

  // Card background color
  Color get cardColor => _isDarkMode
      ? Colors.white.withOpacity(0.1)
      : Colors.white.withOpacity(0.15);

  // Text primary color
  Color get textPrimary => Colors.white;

  // Text secondary color
  Color get textSecondary => _isDarkMode
      ? Colors.white.withOpacity(0.6)
      : Colors.white.withOpacity(0.75);

  // Button background
  Color get buttonBg => _isDarkMode
      ? Colors.white.withOpacity(0.85)
      : Colors.white.withOpacity(0.9);

  // Button text color
  Color get buttonText => const Color(0xFF5B21B6);

  // Accent color
  Color get accentColor => const Color(0xFF10B981);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }
}
