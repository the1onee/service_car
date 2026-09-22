import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// لوحة «Industrial Field Utility»: سليت صناعي، كهرماني للطوارئ، زمردي للحالات الموثقة.
class AppColors {
  static const ink = Color(0xFF0B1C30);
  static const inkSoft = Color(0xFF64748B);

  static const slate = Color(0xFF0F172A);
  static const slateMid = Color(0xFF1E293B);

  /// الاسم القديم للأزرار الأساسية — أصبح السليت الصناعي.
  static const petrol = slate;
  static const petrolDark = Color(0xFF020617);
  static const petrolTint = Color(0xFFF1F5F9);

  static const amber = Color(0xFFF59E0B);
  static const amberDeep = Color(0xFFD97706);
  static const amberTint = Color(0xFFFEF3C7);

  static const emerald = Color(0xFF10B981);
  static const emeraldDeep = Color(0xFF047857);
  static const emeraldTint = Color(0xFFECFDF5);

  static const azure = Color(0xFF2563EB);
  static const azureTint = Color(0xFFEFF6FF);

  static const danger = Color(0xFFEF4444);
  static const dangerTint = Color(0xFFFEF2F2);

  static const success = emerald;

  static const canvas = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const recessed = Color(0xFFF1F5F9);
  static const outline = Color(0xFFE2E8F0);
  static const outlineStrong = Color(0xFFCBD5E1);
}

class AppTheme {
  static const brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [AppColors.slateMid, AppColors.slate, AppColors.petrolDark],
  );

  static const amberGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFBBF24), AppColors.amber],
  );

  static List<BoxShadow> softShadow({Color? color, double opacity = 0.08}) => [
        BoxShadow(
          color: (color ?? AppColors.slate).withValues(alpha: opacity),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> cardShadow() => [
        BoxShadow(
          color: AppColors.slate.withValues(alpha: 0.06),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.slate,
      onPrimary: Colors.white,
      primaryContainer: AppColors.petrolTint,
      onPrimaryContainer: AppColors.petrolDark,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.amberTint,
      onSecondaryContainer: Color(0xFF92400E),
      tertiary: AppColors.emerald,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.emeraldTint,
      onTertiaryContainer: Color(0xFF065F46),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerTint,
      onErrorContainer: Color(0xFF7F1D1D),
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.canvas,
      surfaceContainer: AppColors.recessed,
      surfaceContainerHigh: Color(0xFFE2E8F0),
      surfaceContainerHighest: AppColors.outlineStrong,
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.outline,
      outlineVariant: Color(0xFFF1F5F9),
      inverseSurface: AppColors.slate,
      onInverseSurface: Color(0xFFEAF1FF),
      shadow: AppColors.slate,
      scrim: AppColors.slate,
    );

    final base = GoogleFonts.ibmPlexSansArabicTextTheme();
    final text = base
        .copyWith(
          displaySmall: base.displaySmall
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
          headlineMedium: base.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
          headlineSmall: base.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
          titleLarge: base.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
          titleMedium: base.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.6, fontSize: 16),
          bodyMedium: base.bodyMedium
              ?.copyWith(height: 1.55, fontSize: 14, color: AppColors.inkSoft),
          labelLarge: base.labelLarge
              ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        )
        .apply(displayColor: AppColors.ink, bodyColor: AppColors.ink);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    final label = GoogleFonts.ibmPlexSansArabic(
        fontWeight: FontWeight.w600, fontSize: 15);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.slate,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.slate,
          side: const BorderSide(color: AppColors.slate, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.slate,
          textStyle: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: AppColors.inkSoft,
        suffixIconColor: AppColors.inkSoft,
        hintStyle: GoogleFonts.ibmPlexSansArabic(
            color: const Color(0xFF94A3B8), fontSize: 14),
        labelStyle: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.inkSoft, fontSize: 14),
        floatingLabelStyle: GoogleFonts.ibmPlexSansArabic(
          color: AppColors.amberDeep,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        errorStyle: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.danger, fontSize: 12),
        border: border(AppColors.outlineStrong),
        enabledBorder: border(AppColors.outlineStrong),
        focusedBorder: border(AppColors.amber, 1.6),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.6),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.amberTint,
        side: const BorderSide(color: AppColors.outline),
        labelStyle: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.recessed,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.slate,
        contentTextStyle:
            GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.amber,
        linearTrackColor: AppColors.outline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.inkSoft,
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.outlineStrong;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.emerald;
          return AppColors.outline;
        }),
      ),
    );
  }
}
