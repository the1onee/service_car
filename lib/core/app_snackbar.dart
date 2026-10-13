import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';

/// مكوّن موحد لعرض رسائل SnackBar في التطبيق.
///
/// يوفّر ثلاث طرق:
/// - [showError]: لعرض رسالة خطأ (أحمر).
/// - [showSuccess]: لعرض رسالة نجاح (أخضر).
/// - [showInfo]: لعرض رسالة معلومات (سليت).
class AppSnackBar {
  AppSnackBar._();

  // ─── خطأ ────────────────────────────────────────────────────
  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: AppColors.danger,
      textColor: Colors.white,
      action: action,
    );
  }

  // ─── نجاح ───────────────────────────────────────────────────
  static void showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      backgroundColor: AppColors.emerald,
      textColor: Colors.white,
      action: action,
    );
  }

  // ─── معلومات ────────────────────────────────────────────────
  static void showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: AppColors.slate,
      textColor: Colors.white,
      action: action,
    );
  }

  // ─── المحرك الداخلي ─────────────────────────────────────────
  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 4),
          action: action,
          content: Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTheme.ar(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
