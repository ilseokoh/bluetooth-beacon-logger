import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color surfaceDeep = Color(0xFF020617);         // #020617 (Deep Navy Base Canvas)
  static const Color surface = Color(0xFF0B1326);             // #0B1326 (App Bar / Page Surface)
  static const Color surfaceCard = Color(0xFF1E293B);         // #1E293B (Device Cards)
  static const Color surfaceContainerLowest = Color(0xFF060E20); // #060E20 (Mini Terminal Recess)
  static const Color terminalBg = Color(0xFF000000);          // #000000 (Pure Black Terminal)
  
  static const Color primary = Color(0xFF9ECAFF);             // #9ECAFF (Light Accent Blue)
  static const Color primaryContainer = Color(0xFF2196F3);    // #2196F3 (Start State Blue)
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);  // White text on blue button
  
  static const Color secondary = Color(0xFFFFA9A9);           // #FFA9A9 (Pulsing logging red)
  static const Color secondaryContainer = Color(0xFFF44336);  // #F44336 (Stop State Red)
  static const Color onSecondaryContainer = Color(0xFFFFFFFF); // White text on red button
  
  static const Color signalGreen = Color(0xFF10B981);         // #10B981 (Strong signal green)
  static const Color outlineVariant = Color(0xFF334155);      // #334155 (Low-contrast ghost borders)
  
  static const Color textPrimary = Color(0xFFF8FAFC);         // #F8FAFC (High contrast off-white)
  static const Color textSecondary = Color(0xFF94A3B8);       // #94A3B8 (Muted metadata slate)
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.surfaceDeep,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
    );
  }

  // Geist Typography styles
  static TextStyle headlineLg(BuildContext context) => GoogleFonts.getFont(
        'Geist',
        textStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.33,
        ),
      );

  static TextStyle headlineMd(BuildContext context) => GoogleFonts.getFont(
        'Geist',
        textStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
          height: 1.4,
        ),
      );

  static TextStyle bodyLg(BuildContext context) => GoogleFonts.getFont(
        'Geist',
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      );

  static TextStyle bodyMd(BuildContext context) => GoogleFonts.getFont(
        'Geist',
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
          height: 1.43,
        ),
      );

  // JetBrains Mono Typography styles for technical data
  static TextStyle labelCaps(BuildContext context) => GoogleFonts.getFont(
        'JetBrains Mono',
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.55,
          height: 1.45,
        ),
      );

  static TextStyle dataMono(BuildContext context, {Color color = AppColors.textPrimary, double size = 13}) =>
      GoogleFonts.getFont(
        'JetBrains Mono',
        textStyle: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.normal,
          color: color,
          height: 1.38,
        ),
      );

  static TextStyle dataMonoSm(BuildContext context, {Color color = AppColors.textSecondary}) =>
      GoogleFonts.getFont(
        'JetBrains Mono',
        textStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: color,
          height: 1.27,
        ),
      );
}
