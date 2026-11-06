import 'package:flutter/material.dart';
import 'app_radius.dart';

/// Reusable [BoxDecoration] presets for cards, bottom sheets, and option tiles.
class AppDecorations {
  AppDecorations._();

  static BoxDecoration shadowedCard({
    required Color color,
    required Color shadowColor,
    BorderRadius borderRadius = AppRadius.r12,
    double blurRadius = 8,
    Offset offset = const Offset(0, 2),
  }) => BoxDecoration(
    color: color,
    borderRadius: borderRadius,
    boxShadow: [
      BoxShadow(color: shadowColor, blurRadius: blurRadius, offset: offset),
    ],
  );

  // Drag handle bar shown at top of bottom sheets
  static BoxDecoration dragHandle({required Color color}) =>
      BoxDecoration(color: color, borderRadius: AppRadius.r2);

  // Generic container decoration — fill / rounded corners / border / shadow.
  // Pure pass-through mirroring [BoxDecoration]; all args optional so it fits
  // every non-gradient case (plain fill, outlined card, shadowed card, etc.).
  static BoxDecoration card({
    Color? color,
    BorderRadiusGeometry? borderRadius,
    BoxBorder? border,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
  }) => BoxDecoration(
    color: color,
    borderRadius: borderRadius,
    border: border,
    boxShadow: boxShadow,
    gradient: gradient,
  );

  // Circular container — solid fill, optional border/shadow
  static BoxDecoration circle({
    required Color color,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) => BoxDecoration(
    color: color,
    shape: BoxShape.circle,
    border: border,
    boxShadow: boxShadow,
  );

  // Card with border — color is optional (null = no fill)
  static BoxDecoration outlinedCard({
    Color? color,
    required Color borderColor,
    double borderRadius = 10,
    List<BoxShadow>? boxShadow,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: borderColor),
    boxShadow: boxShadow,
  );

  // Outlined text-field border — reuse across search/filter/input fields
  static OutlineInputBorder inputBorder({
    required Color color,
    double width = 1,
    BorderRadius borderRadius = AppRadius.r10,
  }) => OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(color: color, width: width),
  );

  // Full border set for a themed text field — border/enabled/focused/error/focusedError
  static ({
    OutlineInputBorder border,
    OutlineInputBorder enabledBorder,
    OutlineInputBorder focusedBorder,
    OutlineInputBorder errorBorder,
    OutlineInputBorder focusedErrorBorder,
  })
  inputBorderSet(ColorScheme cs, {BorderRadius borderRadius = AppRadius.r10}) =>
      (
        border: inputBorder(color: cs.outline, borderRadius: borderRadius),
        enabledBorder: inputBorder(
          color: cs.outline,
          borderRadius: borderRadius,
        ),
        focusedBorder: inputBorder(
          color: cs.primary,
          width: 1.5,
          borderRadius: borderRadius,
        ),
        errorBorder: inputBorder(color: cs.error, borderRadius: borderRadius),
        focusedErrorBorder: inputBorder(
          color: cs.error,
          width: 1.5,
          borderRadius: borderRadius,
        ),
      );

  // Selectable option tile — flat, no border, no background fill
  static BoxDecoration selectableOption({
    required Color primaryColor,
    required Color outlineColor,
    required bool selected,
    BorderRadius borderRadius = AppRadius.r12,
  }) => BoxDecoration(color: Colors.transparent, borderRadius: borderRadius);

  // Bottom sheet footer (action / save button row)
  static BoxDecoration bottomSheetFooter({
    required Color color,
    required Color borderColor,
  }) => BoxDecoration(
    color: color,
    border: Border(top: BorderSide(color: borderColor)),
  );
}
