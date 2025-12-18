import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w800),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w700),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}




