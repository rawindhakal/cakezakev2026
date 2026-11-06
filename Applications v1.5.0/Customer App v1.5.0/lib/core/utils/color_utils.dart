import 'package:customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Parses a hex color string (e.g. "#FF6B00" or "FF6B00") into a [Color].
/// Returns [fallback] (default [AppColors.primary]) if the input is null,
/// empty, or invalid — pass [fallback] when the caller needs a color other
/// than the app's default primary (e.g. a per-context theme fallback).
Color parseHexColor(String? hex, {Color fallback = AppColors.primary}) {
  if (hex == null || hex.trim().isEmpty) return fallback;
  try {
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length != 6 && cleaned.length != 8) return fallback;
    final value = int.parse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return Color(value);
  } catch (_) {
    return fallback;
  }
}
