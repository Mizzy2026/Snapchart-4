import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SnapChart dark luxury + glassmorphism theme
class SnapColors {
  static const Color bg = Color(0xFF080A0F);
  static const Color glass = Color(0x8C161A26);
  static const Color glassBorder = Color(0x12FFFFFF);
  static const Color text = Color(0xFFE8EAED);
  static const Color textMuted = Color(0xFF8B93A7);
  static const Color textDim = Color(0xFF5C6578);
  static const Color accent = Color(0xFFB8F200); // electric lime
  static const Color accentDim = Color(0x26B8F200);
  static const Color sell = Color(0xFFFF6B6B);
  static const Color sellDim = Color(0x1FFF6B6B);
  static const Color waiting = Color(0xFFA0A8B8);
  static const Color dna = Color(0xFF7DD3FC);
}

class SnapTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: SnapColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: SnapColors.accent,
        secondary: SnapColors.dna,
        surface: Color(0xFF121620),
        error: SnapColors.sell,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: SnapColors.text,
        displayColor: SnapColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: SnapColors.glass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SnapColors.glassBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SnapColors.accent,
          foregroundColor: const Color(0xFF0A0C10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x59000000),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SnapColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SnapColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0x66B8F200)),
        ),
        labelStyle: const TextStyle(color: SnapColors.textMuted, fontSize: 12),
      ),
    );
  }
}

/// Glass card decoration
BoxDecoration glassDecoration({double radius = 20, Color? borderColor}) {
  return BoxDecoration(
    color: SnapColors.glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? SnapColors.glassBorder),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.45),
        blurRadius: 32,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
