import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// لوحة «Industrial Field Utility»: سليت صناعي، كهرماني للطوارئ، زمردي للحالات الموثقة.
class AppColors {
  static const ink = Color(0xFF0B1C30);
  static const inkSoft = Color(0xFF64748B);

  static const slate = Color(0xFF0F172A);
  static const slateMid = Color(0xFF1E293B);

  /// اللون الأساسي للتطبيق — السليت الصناعي.
  static const primary = slate;

  /// الاسم السابق للأزرار الأساسية (alias للتوافق العكسي مع الكود القديم).
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
  /// متحكم وضع الثيم (داكن / فاتح / حسب النظام) — مفعل افتراضياً على الوضع الداكن.
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// التبديل السريع بين الوضع الداكن والنهاري.
  static void toggleTheme() {
    if (themeModeNotifier.value == ThemeMode.dark) {
      themeModeNotifier.value = ThemeMode.light;
    } else {
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  /// تعيين وضع الثيم يدوياً.
  static void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }

  /// خط عربي مضمّن محلياً — يتجنب فشل تحميل Google Fonts على الويب (مربعات بدل الحروف).
  static const fontFamily = 'NotoSansArabic';

  static TextStyle ar({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

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

    final base = ThemeData(brightness: Brightness.light).textTheme.apply(
          fontFamily: fontFamily,
          displayColor: AppColors.ink,
          bodyColor: AppColors.ink,
        );
    final text = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: fontFamily,
        height: 1.6,
        fontSize: 16,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: fontFamily,
        height: 1.55,
        fontSize: 14,
        color: AppColors.inkSoft,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    final label = ar(fontWeight: FontWeight.w600, fontSize: 15);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
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
        titleTextStyle: ar(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.slate,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
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
          textStyle: ar(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: AppColors.inkSoft,
        suffixIconColor: AppColors.inkSoft,
        hintStyle: ar(color: const Color(0xFF94A3B8), fontSize: 14),
        labelStyle: ar(color: AppColors.inkSoft, fontSize: 14),
        floatingLabelStyle: ar(
          color: AppColors.amberDeep,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        errorStyle: ar(color: AppColors.danger, fontSize: 12),
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
        backgroundColor: AppColors.recessed,
        selectedColor: AppColors.amber,
        disabledColor: AppColors.recessed,
        side: const BorderSide(color: AppColors.outline),
        labelStyle: ar(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.ink,
        ),
        secondaryLabelStyle: ar(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        checkmarkColor: AppColors.ink,
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
        contentTextStyle: ar(color: Colors.white, fontSize: 14),
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
        titleTextStyle: ar(
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

  // ═══════════════════════════════════════════════════════════════
  //  الوضع الداكن — Industrial Night
  // ═══════════════════════════════════════════════════════════════

  /// ألوان خاصة بالوضع الداكن.
  static const _darkCanvas = Color(0xFF0B1120);
  static const _darkSurface = Color(0xFF1A2332);
  static const _darkRecessed = Color(0xFF0F172A);
  static const _darkOutline = Color(0xFF2D3B4E);
  static const _darkOutlineStrong = Color(0xFF3E4F65);
  static const _darkInk = Color(0xFFE2E8F0);
  static const _darkInkSoft = Color(0xFF94A3B8);

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.amber,
      onPrimary: AppColors.petrolDark,
      primaryContainer: Color(0xFF422006),
      onPrimaryContainer: AppColors.amberTint,
      secondary: AppColors.amber,
      onSecondary: AppColors.petrolDark,
      secondaryContainer: Color(0xFF451A03),
      onSecondaryContainer: AppColors.amberTint,
      tertiary: AppColors.emerald,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF064E3B),
      onTertiaryContainer: AppColors.emeraldTint,
      error: Color(0xFFFCA5A5),
      onError: Color(0xFF7F1D1D),
      errorContainer: Color(0xFF991B1B),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: _darkSurface,
      onSurface: _darkInk,
      surfaceContainerLowest: _darkCanvas,
      surfaceContainerLow: Color(0xFF111827),
      surfaceContainer: _darkRecessed,
      surfaceContainerHigh: _darkOutline,
      surfaceContainerHighest: _darkOutlineStrong,
      onSurfaceVariant: _darkInkSoft,
      outline: _darkOutline,
      outlineVariant: Color(0xFF1E293B),
      inverseSurface: Color(0xFFE2E8F0),
      onInverseSurface: AppColors.petrolDark,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final base = ThemeData(brightness: Brightness.dark).textTheme.apply(
          fontFamily: fontFamily,
          displayColor: _darkInk,
          bodyColor: _darkInk,
        );
    final text = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: fontFamily,
        height: 1.6,
        fontSize: 16,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: fontFamily,
        height: 1.55,
        fontSize: 14,
        color: _darkInkSoft,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    final label = ar(fontWeight: FontWeight.w600, fontSize: 15);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: _darkCanvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkCanvas,
        foregroundColor: _darkInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: ar(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: _darkInk,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.petrolDark,
          minimumSize: const Size(64, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: AppColors.amber,
          side: const BorderSide(color: AppColors.amber, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.amber,
          textStyle: ar(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: _darkInkSoft,
        suffixIconColor: _darkInkSoft,
        hintStyle: ar(color: const Color(0xFF64748B), fontSize: 14),
        labelStyle: ar(color: _darkInkSoft, fontSize: 14),
        floatingLabelStyle: ar(
          color: AppColors.amber,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        errorStyle: ar(color: const Color(0xFFFCA5A5), fontSize: 12),
        border: border(_darkOutline),
        enabledBorder: border(_darkOutline),
        focusedBorder: border(AppColors.amber, 1.6),
        errorBorder: border(const Color(0xFFFCA5A5)),
        focusedErrorBorder: border(const Color(0xFFFCA5A5), 1.6),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkOutline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkRecessed,
        selectedColor: AppColors.amber,
        disabledColor: _darkRecessed,
        side: const BorderSide(color: _darkOutline),
        labelStyle: ar(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: _darkInk,
        ),
        secondaryLabelStyle: ar(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: _darkInk,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        checkmarkColor: AppColors.petrolDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkOutline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _darkSurface,
        contentTextStyle: ar(color: _darkInk, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.amber,
        linearTrackColor: _darkOutline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: _darkInkSoft,
        titleTextStyle: ar(
          color: _darkInk,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.petrolDark;
          return _darkOutlineStrong;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.emerald;
          return _darkOutline;
        }),
      ),
    );
  }
}
