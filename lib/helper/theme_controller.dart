import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static const String _themeKey = 'is_dark_mode';

  // Defaults to Light Mode as requested by user
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDark => themeMode.value == ThemeMode.dark;

  // Initialize theme from SharedPreferences (Defaults to Light Mode if not set)
  static Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkSaved = prefs.getBool(_themeKey);

    if (isDarkSaved != null) {
      themeMode.value = isDarkSaved ? ThemeMode.dark : ThemeMode.light;
    } else {
      // Default to Light Mode on first open
      themeMode.value = ThemeMode.light;
    }
  }

  // Toggle theme and persist in SharedPreferences
  static Future<void> toggleTheme(bool enableDark) async {
    themeMode.value = enableDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, enableDark);
  }

  // Dynamic Theme Colors
  static Color get bgColor => isDark ? Colors.black : const Color(0xFFF2F2F7);
  static Color get cardColor => isDark ? const Color(0xFF1C1C1E) : Colors.white;
  static Color get headerColor => isDark ? const Color(0xFF161618) : const Color(0xFFF6F6F6);
  static Color get textColor => isDark ? Colors.white : Colors.black;
  static Color get subtextColor => isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  static Color get dividerColor => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  static Color get receivedBubbleColor => isDark ? const Color(0xFF26252A) : const Color(0xFFE9E9EB);
}
