import 'package:flutter/material.dart';

/// Parses a hex color string (e.g. "#FF6B00" or "FF6B00") into a [Color].
/// Returns null if [hex] is null, empty, or not a valid hex value — callers
/// fall back to their own contextual default (e.g. `?? theme.primaryColor`).
Color? parseHomeHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final s = hex.replaceAll('#', '');
  final val = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
  return val != null ? Color(val) : null;
}
