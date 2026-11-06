import 'package:deliveryboy/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Parses a hex color string (e.g. "#2A55E5" or "2A55E5") into a [Color].
/// Returns [AppColors.primary] if the input is null, empty, or invalid.
Color parseHexColor(String? hex) {
  if (hex == null || hex.trim().isEmpty) return AppColors.primary;
  try {
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length != 6 && cleaned.length != 8) return AppColors.primary;
    final value = int.parse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return Color(value);
  } catch (e) {
    return AppColors.primary;
  }
}
