import 'package:flutter/material.dart';

class CatppuccinTheme {
  static const Color base = Color(0xFF1e1e2e);
  static const Color mantle = Color(0xFF181825);
  static const Color crust = Color(0xFF11111b);
  static const Color text = Color(0xFFcdd6f4);
  static const Color subtext0 = Color(0xFFa6adc8);
  static const Color overlay0 = Color(0xFF6c7086);
  static const Color surface0 = Color(0xFF313244);
  static const Color blue = Color(0xFF89b4fa);
  static const Color red = Color(0xFFf38ba8);
  static const Color green = Color(0xFFa6e3a1);
  static const Color yellow = Color(0xFFf9e2af);
  static const Color lavender = Color(0xFFb4befe);

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: base,
      primaryColor: lavender,
      colorScheme: const ColorScheme.dark(
        primary: lavender,
        secondary: blue,
        surface: surface0,
        error: red,
        onPrimary: base,
        onSecondary: base,
        onSurface: text,
        onError: base,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: base,
        foregroundColor: text,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: mantle,
        selectedItemColor: lavender,
        unselectedItemColor: overlay0,
      ),
    );
  }
}
