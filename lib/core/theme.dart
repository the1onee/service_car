import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// لوحة ألوان التطبيق: أزرق بترولي عميق للهوية، كهرماني للتنبيه،
/// أزرق سماوي للمعلومات، مع رماديات دافئة للأسطح.
class AppColors {
  static const ink = Color(0xFF0B1F2A);
  static const inkSoft = Color(0xFF5A6C77);

  static const petrol = Color(0xFF0E6B5C);
  static const petrolDark = Color(0xFF07463C);
  static const petrolTint = Color(0xFFE3F2EE);

  static const amber = Color(0xFFF0A02A);
  static const amberTint = Color(0xFFFDF2DE);

  static const azure = Color(0xFF2F6FE4);
  static const azureTint = Color(0xFFE7EFFD);

  static const danger = Color(0xFFD64550);
  static const dangerTint = Color(0xFFFCE9EA);

  static const success = Color(0xFF15904F);

  static const canvas = Color(0xFFF4F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const outline = Color(0xFFDCE4E8);
}

class AppTheme {
  /// تدرّج الهوية المستخدم في الترويسات وأزرار الإجراء الرئيسي.
  static const brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF11836F), AppColors.petrol, Color(0xFF0A3F45)],
  );

  static const amberGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFF7B94A), AppColors.amber],
  );

  static List<BoxShadow> softShadow({Color? color, double opacity = 0.10}) => [
        BoxShadow(
          color: (color ?? AppColors.ink).withValues(alpha: opacity),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.petrol,
      onPrimary: Colors.white,
      primaryContainer: AppColors.petrolTint,
      onPrimaryContainer: AppColors.petrolDark,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.amberTint,
      onSecondaryContainer: Color(0xFF6B4400),
      tertiary: AppColors.azure,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.azureTint,
      onTertiaryContainer: Color(0xFF10366F),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerTint,
      onErrorContainer: Color(0xFF7A1F26),
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFAFCFC),
      surfaceContainer: AppColors.canvas,
      surfaceContainerHigh: Color(0xFFEDF2F4),
      surfaceContainerHighest: Color(0xFFE6EDEF),
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.outline,
      outlineVariant: Color(0xFFEDF1F3),
      inverseSurface: AppColors.ink,
      onInverseSurface: Colors.white,
      shadow: AppColors.ink,
      scrim: AppColors.ink,
    );

    final base = GoogleFonts.cairoTextTheme();
    final text = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.6),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.6, color: AppColors.inkSoft),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ).apply(displayColor: AppColors.ink, bodyColor: AppColors.ink);

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.cairo(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.petrol,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.petrol,
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        prefixIconColor: AppColors.inkSoft,
        suffixIconColor: AppColors.inkSoft,
        hintStyle: GoogleFonts.cairo(color: const Color(0xFF9FAEB6), fontSize: 14),
        labelStyle: GoogleFonts.cairo(color: AppColors.inkSoft, fontSize: 14),
        floatingLabelStyle: GoogleFonts.cairo(
          color: AppColors.petrol,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        errorStyle: GoogleFonts.cairo(color: AppColors.danger, fontSize: 12),
        border: border(AppColors.outline),
        enabledBorder: border(AppColors.outline),
        focusedBorder: border(AppColors.petrol, 1.6),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.6),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.petrolTint,
        side: const BorderSide(color: AppColors.outline),
        labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.petrol,
        linearTrackColor: AppColors.petrolTint,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkSoft,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}
