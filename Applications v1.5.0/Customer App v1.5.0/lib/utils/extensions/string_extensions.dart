import 'package:flutter/material.dart';

extension NullableStringExtension on String? {
  /// True for a non-null, non-empty string that isn't the literal 'null' —
  /// the API sometimes serializes a missing field as the string "null"
  /// instead of omitting it, so a plain null/empty check isn't enough.
  bool get hasValue => this != null && this!.isNotEmpty && this != 'null';
}

extension StringColorExtension on String? {
  /// Parses a hex color string ("#RRGGBB" or "RRGGBB"/"RRGGBBAA") into a
  /// [Color]. The 8-digit form is CSS-style with alpha last (the admin
  /// panel's color picker exports it that way), not Flutter's native
  /// AARRGGBB — reordered below so Color() gets the alpha channel first.
  /// Returns null for null/empty/unparsable input.
  Color? toColor() {
    final hex = this;
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 8) {
      final rgb = cleaned.substring(0, 6);
      final alpha = cleaned.substring(6, 8);
      final value = int.tryParse('$alpha$rgb', radix: 16);
      return value != null ? Color(value) : null;
    }
    final value = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return value != null ? Color(value) : null;
  }
}
