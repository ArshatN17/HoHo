import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color palette
  static const Color primaryCoral = Color(0xFFEA6A5E);
  static const Color softGreen = Color(0xFF475C4E);
  static const Color offWhite = Color(0xFFF7F5F2);
  static const Color darkGray = Color(0xFF2E2E2E);
  static const Color white = Color(0xFFFFFFFF);
  
  // Additional colors for UI elements
  static const Color lightCoral = Color(0xFFF9C4BD);
  static const Color paleGreen = Color(0xFFD3E0D9);
  static const Color lightGray = Color(0xFFE5E5E5);
  
  // Elevation
  static const double cardElevation = 2.0;
  static BorderRadius defaultBorderRadius = BorderRadius.circular(16.0);
  static BorderRadius buttonBorderRadius = BorderRadius.circular(24.0);
  
  // Create theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryCoral,
        secondary: softGreen,
        surface: white,
        background: offWhite,
        onPrimary: white,
        onSecondary: white,
        onSurface: darkGray,
        onBackground: darkGray,
      ),
      
      // Customize app bar
      appBarTheme: AppBarTheme(
        backgroundColor: offWhite,
        foregroundColor: darkGray,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkGray,
        ),
        iconTheme: const IconThemeData(color: softGreen),
      ),
      
      // Scaffold background color
      scaffoldBackgroundColor: offWhite,
      
      // Text theme
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: darkGray,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 24, 
          fontWeight: FontWeight.bold,
          color: darkGray,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 20, 
          fontWeight: FontWeight.w600,
          color: darkGray,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          color: darkGray,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: darkGray,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          color: darkGray,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: white,
        ),
      ),
      
      // Customize buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCoral,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: buttonBorderRadius,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryCoral,
          shape: RoundedRectangleBorder(
            borderRadius: buttonBorderRadius,
            side: const BorderSide(color: primaryCoral, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: softGreen,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Card theme
      cardTheme: CardTheme(
        color: white,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        shadowColor: darkGray.withOpacity(0.1),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: defaultBorderRadius,
          borderSide: const BorderSide(color: primaryCoral, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: darkGray.withOpacity(0.5),
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: darkGray,
        ),
      ),
      
      // Tab bar theme
      tabBarTheme: TabBarTheme(
        labelColor: primaryCoral,
        unselectedLabelColor: darkGray.withOpacity(0.6),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        indicator: BoxDecoration(
          borderRadius: defaultBorderRadius,
          color: lightCoral.withOpacity(0.3),
        ),
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: lightGray,
        thickness: 1,
        space: 24,
      ),
      
      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: primaryCoral,
        unselectedItemColor: darkGray,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryCoral,
        foregroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: paleGreen,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: softGreen,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        selectedColor: primaryCoral,
        secondaryLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: white,
          fontWeight: FontWeight.bold,
        ),
        showCheckmark: true,
        checkmarkColor: white,
        disabledColor: lightGray,
        selectedShadowColor: primaryCoral.withOpacity(0.4),
        elevation: 0,
        pressElevation: 2,
      ),
      
      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkGray,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          color: darkGray,
        ),
      ),
    );
  }
} 