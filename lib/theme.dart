import 'package:flutter/material.dart';

class T {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const card = Color(0xFF141414);
  static const border = Color(0xFF262626);
  static const red = Color(0xFFFF1E1E);
  static const white = Color(0xFFFFFFFF);
  static const dim = Color(0xFF9A9A9A);
  static const faint = Color(0xFF5A5A5A);

  static const mono = 'ShareTechMono';
  static const ui = 'Rajdhani';

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        fontFamily: ui,
        colorScheme: const ColorScheme.dark(
          primary: red,
          secondary: white,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          iconTheme: IconThemeData(color: white),
          titleTextStyle: TextStyle(
            fontFamily: mono,
            color: white,
            fontSize: 15,
            letterSpacing: 3,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: card,
          contentTextStyle: TextStyle(fontFamily: ui, color: white),
        ),
      );
}
