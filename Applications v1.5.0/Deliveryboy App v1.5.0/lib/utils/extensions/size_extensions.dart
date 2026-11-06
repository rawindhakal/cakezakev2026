import 'package:flutter/material.dart';

/// Responsive sizing helpers, split out from [ContextExtensions] to keep
/// theme/localization concerns separate from screen-size math.
///
/// Uses the scoped `MediaQuery.sizeOf` / `paddingOf` / `viewInsetsOf`
/// accessors instead of `MediaQuery.of(context)` so widgets only rebuild
/// when the specific value they read changes, not on every MediaQuery
/// change (orientation, brightness, text scale, etc).
extension SizeExtensions on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Height of the status bar / notch. Add to a widget's own top
  /// padding/spacing for content pinned under the status bar.
  double get topSafePadding => MediaQuery.paddingOf(this).top;

  /// Height of the system nav bar (3-button nav) / home indicator (gesture
  /// nav). Add this to a widget's own bottom padding/spacing for
  /// bottom-pinned bars and bottom sheets — don't wrap the whole widget in
  /// `SafeArea`, which insets its background too and leaves a visible gap
  /// above the system nav bar instead of the design extending flush to it.
  double get bottomSafePadding => MediaQuery.paddingOf(this).bottom;

  /// Height of the on-screen keyboard when open, `0` when closed. Use to
  /// push bottom-pinned content (e.g. a bottom-sheet text field) above it.
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  /// Fraction of screen width, e.g. `context.widthFraction(0.72)`.
  double widthFraction(double fraction) => screenWidth * fraction;

  /// Fraction of screen height, e.g. `context.heightFraction(0.5)`.
  double heightFraction(double fraction) => screenHeight * fraction;
}
