import 'dart:convert';

import 'package:flutter/material.dart';

/// يعرض صورة من رابط HTTPS أو data URL قديم (base64) للتوافق مع السجلات السابقة.
class AppNetworkOrDataImage extends StatelessWidget {
  const AppNetworkOrDataImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.errorColor = const Color(0xFFEFF4FF),
    this.showErrorLabel = false,
  });

  final String source;
  final BoxFit fit;
  final Color errorColor;
  final bool showErrorLabel;

  Widget get _error => ColoredBox(
        color: errorColor,
        child: showErrorLabel
            ? const Center(child: Text('تعذر عرض الصورة'))
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final raw = source.trim();
    if (raw.isEmpty) return _error;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Image.network(
        raw,
        fit: fit,
        errorBuilder: (_, __, ___) => _error,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: errorColor,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    if (raw.startsWith('data:')) {
      try {
        final comma = raw.indexOf(',');
        final b64 = comma >= 0 ? raw.substring(comma + 1) : raw;
        return Image.memory(
          base64Decode(b64),
          fit: fit,
          errorBuilder: (_, __, ___) => _error,
        );
      } catch (_) {
        return _error;
      }
    }

    // رابط نسبي أو قيمة غير معروفة.
    return _error;
  }
}
