import 'package:flutter/material.dart';

/// Colours and text styles for the app's frosted-glass look.
///
/// Surfaces are translucent, so the theme keeps solid fills out of the way and
/// lets [GlassSurface] (lib/widgets/glass.dart) paint them over the gradient
/// backdrop instead.
class AppTheme {
  static const teal = Color(0xFF007F73);
  static const navy = Color(0xFF173A43);
  static const mint = Color(0xFF8CE1D2);
  static const sky = Color(0xFF4FB9D8);

  /// Backdrop the glass sits on.
  static const backdropTop = Color(0xFFF2F9F8);
  static const backdropBottom = Color(0xFFE2EFF0);

  /// Fill of a pane of glass: brighter at the top-left, like lit glass.
  static const glassHigh = Color(0x99FFFFFF);
  static const glassLow = Color(0x4DFFFFFF);
  static const glassBorder = Color(0x80FFFFFF);
  static const glassShadow = Color(0x14173A43);

  static const textMuted = Color(0xFF5B7076);

  /// Bundled in pubspec.yaml at weights 400/500/600/700.
  static const fontFamily = 'RobotoSlab';

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      // The gradient backdrop shows through; a solid colour here would hide it.
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: teal,
            brightness: Brightness.light,
          ).copyWith(
            primary: teal,
            secondary: mint,
            surface: Colors.white,
            surfaceTint: Colors.transparent,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: navy,
          letterSpacing: -0.1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x8FFFFFFF),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFF8A9CA1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: _inputBorder(const Color(0x66FFFFFF)),
        enabledBorder: _inputBorder(const Color(0x66FFFFFF)),
        focusedBorder: _inputBorder(teal, width: 1.4),
        errorBorder: _inputBorder(const Color(0xFFD26B6B)),
        focusedErrorBorder: _inputBorder(const Color(0xFFD26B6B), width: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          backgroundColor: const Color(0x73FFFFFF),
          side: const BorderSide(color: glassBorder),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Cards are drawn by GlassSurface; this keeps any plain Card in step.
      cardTheme: CardThemeData(
        color: glassHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: glassBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xF2FFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: glassBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy.withValues(alpha: 0.95),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x73FFFFFF),
        selectedColor: teal,
        side: const BorderSide(color: glassBorder),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: navy,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x33173A43),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: teal),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: navy,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: navy,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: navy),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: navy),
        bodyLarge: TextStyle(color: textMuted, height: 1.4),
        bodyMedium: TextStyle(color: textMuted, height: 1.35),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, color: navy),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
}
