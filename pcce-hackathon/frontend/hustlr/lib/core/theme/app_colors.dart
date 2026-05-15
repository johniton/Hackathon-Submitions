import 'package:flutter/material.dart';

class AppColors {
  // ── Requested Strict Palette ───────────────────────────────────────────────
  static const Color primary = Color(0xFF8DBCC7);
  static const Color primaryDark = Color(0xFF8DBCC7);
  static const Color primaryLight = Color(0xFFC4E1E6);

  static const Color accent = Color(0xFFA4CCD9);
  static const Color accentOrange = Color(0xFFEBFFD8);
  static const Color accentPurple = Color(0xFF8DBCC7);
  static const Color accentPink = Color(0xFFC4E1E6);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceDark2 = Color(0xFF2C2C2C);

  // Text
  static const Color textPrimaryLight = Color(0xFF333333);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color textPrimaryDark = Color(0xFFF0F5ED);
  static const Color textSecondaryDark = Color(0xFF9AB5A4);

  // Status
  static const Color success = Color(0xFF8DBCC7);
  static const Color error = Color(0xFFE57373);
  static const Color warning = Color(0xFFFFB74D);
  static const Color info = Color(0xFFA4CCD9);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8DBCC7), Color(0xFFA4CCD9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFFA4CCD9), Color(0xFFC4E1E6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFC4E1E6), Color(0xFFEBFFD8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8DBCC7), Color(0xFFC4E1E6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orchidGradient = LinearGradient(
    colors: [Color(0xFFA4CCD9), Color(0xFFEBFFD8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF121212), Color(0xFF1E1E1E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
