import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFF7A1A);
  static const secondary = Color(0xFFFFB347);
  static const bg = Color(0xFFF5F5F5);
  static const card = Colors.white;
  static const text = Colors.black87;
}

class AppTheme {
  static ThemeData light = ThemeData(
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Sans',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  );
}