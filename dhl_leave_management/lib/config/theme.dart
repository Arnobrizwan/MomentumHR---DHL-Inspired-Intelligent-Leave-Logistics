import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DHLTheme {
  // DHL Color Palette
  static const Color dhlRed = Color(0xFFD40511);
  static const Color dhlYellow = Color(0xFFFFCC00);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF333333);
  static const Color accentBlue = Color(0xFF007ACC);
  
  // Status Colors
  static const Color pendingColor = Color(0xFFFFA500);
  static const Color approvedColor = Color(0xFF28A745);
  static const Color rejectedColor = Color(0xFFDC3545);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: dhlRed,
      scaffoldBackgroundColor: lightGray,
      colorScheme: ColorScheme.light(
        primary: dhlRed,
        secondary: dhlYellow,
        surface: Colors.white,
        background: lightGray,
        error: rejectedColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: dhlRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dhlRed,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dhlRed,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dhlRed,
          side: const BorderSide(color: dhlRed),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dhlRed, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
      ),
      textTheme: GoogleFonts.nunitoSansTextTheme().copyWith(
        displayLarge: const TextStyle(color: darkGray),
        displayMedium: const TextStyle(color: darkGray),
        displaySmall: const TextStyle(color: darkGray),
        headlineMedium: const TextStyle(color: darkGray, fontWeight: FontWeight.bold),
        headlineSmall: const TextStyle(color: darkGray, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: darkGray, fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(color: darkGray),
        bodyMedium: const TextStyle(color: darkGray),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: MaterialStatePropertyAll(lightGray),
        dataRowColor: MaterialStatePropertyAll(Colors.white),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: darkGray,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightGray,
        thickness: 1,
        space: 1,
      ),
    );
  }
}