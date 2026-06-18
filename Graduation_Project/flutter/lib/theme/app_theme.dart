import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0097A7);
  static const Color primaryDark = Color(0xFF00838F);
  static const Color primaryLight = Color(0xFF4DD0E1);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFF44336);

  // ── Light Mode Colors ─────────────────────────────────────────────────────
  static const Color background = Color(0xFFF5F7F8);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF0A0A0A);
  static const Color textSecondary = Color(0xFF717182);
  static const Color inputBg = Color(0xFFF3F3F5);
  static const Color borderColor = Color(0x1A000000);
  static const Color dividerColor = Color(0xFFE8E8EC);

  // ── Dark Mode — exact Figma values ───────────────────────────────────────
  static const Color darkBackground = Color(0xFF121212); // Standard dark bg
  static const Color darkCardBg = Color(0xFF1E1E1E); // Lighter surface
  static const Color darkRowBg = Color(0xFF262626);
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFA1A1A1);
  static const Color darkInputBg = Color(0xFF262626);
  static const Color darkBorderColor = Color(0xFF2C2C2C);
  static const Color darkDividerColor = Color(0xFF2C2C2C);

  // ── Stat card colors (used in both modes per Figma) ───────────────────────
  static const Color statBlueBg = Color(0xFFEFF6FF);
  static const Color statBlueFg = Color(0xFF1C398E);
  static const Color statBlueLabel = Color(0xFF1447E6);
  static const Color statGreenBg = Color(0xFFF0FDF4);
  static const Color statGreenFg = Color(0xFF0D542B);
  static const Color statGreenLabel = Color(0xFF008236);
  static const Color statPurpleBg = Color(0xFFFAF5FF);
  static const Color statPurpleFg = Color(0xFF59168B);
  static const Color statPurpleLabel = Color(0xFF8200DB);
  static const Color statOrangeBg = Color(0xFFFFF7ED);
  static const Color statOrangeFg = Color(0xFF7E2A0C);
  static const Color statOrangeLabel = Color(0xFFCA3500);

  // ── Light badge colors ────────────────────────────────────────────────────
  static const Color badgeBlue = Color(0xFFE3F2FD);
  static const Color badgeBlueFg = Color(0xFF1565C0);
  static const Color badgeGreen = Color(0xFFE8F5E9);
  static const Color badgeGreenFg = Color(0xFF2E7D32);
  static const Color badgeOrange = Color(0xFFFFF3E0);
  static const Color badgeOrangeFg = Color(0xFFE65100);

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: primary,
          surface: cardBg,
          onSurface: textPrimary,
          surfaceContainerHighest: inputBg,
        ),
        scaffoldBackgroundColor: background,
        textTheme: GoogleFonts.dmSansTextTheme().copyWith(
          headlineLarge: GoogleFonts.dmSans(
              fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
          headlineMedium: GoogleFonts.dmSans(
              fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
          headlineSmall: GoogleFonts.dmSans(
              fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
          titleLarge: GoogleFonts.dmSans(
              fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
          titleMedium: GoogleFonts.dmSans(
              fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
          bodyLarge: GoogleFonts.dmSans(
              fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
          bodyMedium: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
          bodySmall: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
          labelLarge: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.dmSans(
              fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
          iconTheme: const IconThemeData(color: textPrimary),
          systemOverlayStyle: SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderColor, width: 1.18),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: GoogleFonts.dmSans(color: textSecondary, fontSize: 14),
          prefixIconColor: textSecondary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: primary,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dividerTheme:
            const DividerThemeData(color: dividerColor, thickness: 1, space: 1),
        chipTheme: ChipThemeData(
          backgroundColor: badgeBlue,
          labelStyle:
              GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        ),
      );

  // ── Dark Theme — Enhanced for Professional Look ──────────────────────────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primary,
          secondary: primary,
          surface: darkCardBg,
          onSurface: darkTextPrimary,
          surfaceContainerHighest: darkRowBg,
          outline: darkBorderColor,
        ),
        scaffoldBackgroundColor: darkBackground,
        textTheme: GoogleFonts.dmSansTextTheme().copyWith(
          headlineLarge: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: darkTextPrimary),
          headlineMedium: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: darkTextPrimary),
          headlineSmall: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: darkTextPrimary),
          titleLarge: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: darkTextPrimary),
          titleMedium: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: darkTextPrimary),
          bodyLarge: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: darkTextPrimary),
          bodyMedium: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: darkTextSecondary),
          bodySmall: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: darkTextSecondary),
          labelLarge: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: darkTextPrimary),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: darkCardBg,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkTextPrimary),
          iconTheme: const IconThemeData(color: darkTextPrimary),
          systemOverlayStyle: SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent),
        ),
        cardTheme: CardThemeData(
          color: darkCardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: darkBorderColor, width: 1.18),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkInputBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: GoogleFonts.dmSans(color: darkTextSecondary, fontSize: 14),
          prefixIconColor: darkTextSecondary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkCardBg,
          selectedItemColor: primary,
          unselectedItemColor: darkTextSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dividerTheme: const DividerThemeData(
            color: darkDividerColor, thickness: 1, space: 1),
        chipTheme: ChipThemeData(
          backgroundColor: darkRowBg,
          labelStyle: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: darkTextPrimary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: darkCardBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        ),
      );
}
