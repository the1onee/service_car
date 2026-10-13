import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// مكوّنات وأيقونات SVG الخاصة بالتطبيق (عروض الفني والورشة).
class AppSvgIcons {
  AppSvgIcons._();

  static const String techOffer = 'assets/icons/tech_offer.svg';
  static const String workshopOffer = 'assets/icons/workshop_offer.svg';

  /// أيقونة عرض الفني (SVG)
  static Widget tech({
    double size = 32,
    Color? color,
  }) {
    return SvgPicture.asset(
      techOffer,
      width: size,
      height: size,
      colorFilter:
          color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  /// أيقونة عرض الورشة (SVG)
  static Widget workshop({
    double size = 32,
    Color? color,
  }) {
    return SvgPicture.asset(
      workshopOffer,
      width: size,
      height: size,
      colorFilter:
          color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  /// أيقونة تناسب نوع العرض (ورشة أو فني) تلقائياً
  static Widget offerIcon({
    required bool isWorkshop,
    double size = 32,
    Color? color,
  }) {
    return isWorkshop
        ? workshop(size: size, color: color)
        : tech(size: size, color: color);
  }
}
