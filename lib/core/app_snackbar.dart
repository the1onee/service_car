import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';

/// مكوّن موحد لعرض رسائل SnackBar في التطبيق (أعلى الشاشة، 5 ثوانٍ).
///
/// يوفّر:
/// - [showError] / [showSuccess] / [showInfo] عبر [BuildContext]
/// - [showOnMessenger] عند توفر [ScaffoldMessengerState] فقط (مثل FCM)
class AppSnackBar {
  AppSnackBar._();

  static const _duration = Duration(seconds: 5);
  static const _approxHeight = 72.0;

  // ─── خطأ ────────────────────────────────────────────────────
  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(
      ScaffoldMessenger.of(context),
      context: context,
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
      ScaffoldMessenger.of(context),
      context: context,
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
      ScaffoldMessenger.of(context),
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: AppColors.slate,
      textColor: Colors.white,
      action: action,
    );
  }

  /// لعرض تنبيه من [ScaffoldMessengerState] بدون [BuildContext] مباشر (FCM).
  static void showOnMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    SnackBarAction? action,
    IconData icon = Icons.info_outline_rounded,
    Color backgroundColor = AppColors.slate,
    Color textColor = Colors.white,
  }) {
    _show(
      messenger,
      context: messenger.context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      textColor: textColor,
      action: action,
    );
  }

  static EdgeInsets _topMargin(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top + 8;
    final bottom = (media.size.height - top - _approxHeight).clamp(0.0, double.infinity);
    return EdgeInsets.fromLTRB(16, 0, 16, bottom);
  }

  // ─── المحرك الداخلي ─────────────────────────────────────────
  static void _show(
    ScaffoldMessengerState messenger, {
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    SnackBarAction? action,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: _topMargin(context),
          duration: _duration,
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
