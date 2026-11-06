import 'package:customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import 'package:customer/core/theme/app_radius.dart';

class AppDecorations {
  AppDecorations._();

  // Drag handle bar shown at top of bottom sheets
  static BoxDecoration dragHandle({required Color color}) =>
      BoxDecoration(color: color, borderRadius: AppRadius.r2);

  // Square icon box with primary-tinted background
  static BoxDecoration primaryIconBox({
    required Color color,
    double borderRadius = 10,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(borderRadius),
  );

  // Card with border — color is optional (null = no fill), pass boxShadow when needed
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

  // Card with drop shadow
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

  // Bottom sheet container body
  static BoxDecoration bottomSheet({
    required Color color,
    BorderRadius borderRadius = AppRadius.bottomSheetRadius,
    List<BoxShadow>? boxShadow,
  }) => BoxDecoration(
    color: color,
    borderRadius: borderRadius,
    boxShadow: boxShadow,
  );

  // Bottom sheet footer (action / save button row)
  static BoxDecoration bottomSheetFooter({
    required Color color,
    required Color borderColor,
  }) => BoxDecoration(
    color: color,
    border: Border(top: BorderSide(color: borderColor)),
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

  // Quantity control surface — shared by the product CartButton and the
  // checkout qty stepper so both read as the same component. [filled] is the
  // active/stepper state (primary fill, primary-tinted lift); when false it's
  // the idle "ADD" state (surface fill, neutral lift). [softShadow] dials the
  // lift down for shorter/inline controls such as the checkout stepper.
  static BoxDecoration cartControl({
    required ColorScheme cs,
    required bool filled,
    bool softShadow = false,
    BorderRadius borderRadius = AppRadius.r10,
  }) => BoxDecoration(
    color: filled ? cs.primary : cs.surface,
    borderRadius: borderRadius,
    border: Border.all(color: cs.primary, width: 0.5),
    boxShadow: [
      if (filled)
        BoxShadow(
          color: cs.primary.withValues(alpha: softShadow ? 0.22 : 0.40),
          blurRadius: softShadow ? 6 : 10,
          offset: Offset(0, softShadow ? 2 : 4),
        )
      else
        BoxShadow(
          color: cs.shadow.withValues(alpha: 0.10),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
    ],
  );

  // Circular icon badge — color is caller-supplied (e.g. selected-card surface color)
  static BoxDecoration circleIconBadge({required Color color}) =>
      BoxDecoration(color: color, shape: .circle);

  // Generic box builder — for one-off decorations that don't fit a named
  // preset above (gradient fills, per-call border widths, conditional
  // shadows, etc). Prefer a named preset when the shape matches one.
  static BoxDecoration box({
    Color? color,
    Gradient? gradient,
    BorderRadiusGeometry? borderRadius,
    BoxShape shape = BoxShape.rectangle,
    BoxBorder? border,
    List<BoxShadow>? boxShadow,
    DecorationImage? image,
  }) => BoxDecoration(
    color: color,
    gradient: gradient,
    borderRadius: shape == BoxShape.circle ? null : borderRadius,
    shape: shape,
    border: border,
    boxShadow: boxShadow,
    image: image,
  );

  // Selectable option tile — flat, no border, no background fill regardless
  // of selection state (Radio + text color already convey selection).
  static BoxDecoration selectableOption({
    BorderRadius borderRadius = AppRadius.r12,
  }) => BoxDecoration(color: AppColors.transparent, borderRadius: borderRadius);
}
