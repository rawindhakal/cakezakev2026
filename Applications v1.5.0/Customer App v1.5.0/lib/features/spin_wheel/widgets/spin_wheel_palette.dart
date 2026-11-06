import 'package:customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Colours for the spin-wheel dialog chrome (background, title, scrim).
///
/// Wheel-specific colours (ring, slices, hub) are NOT here: they come from the
/// `spin_wheel` config API (`campaign.theme`) so the backend can re-theme the
/// wheel without an app update. The board / tray / result card keep their own
/// purple palette privately in their files, next to the code that paints them.
abstract final class SpinWheelPalette {
  /// Near-black at the top edge of the dialog. Also the dialog's barrier
  /// color and the status-bar color, so the screen reads as one surface.
  static const backgroundTop = AppColors.spinWheelDialogBgTop;

  /// Near-black at the bottom edge of the dialog; also the nav-bar color.
  static const backgroundBottom = AppColors.spinWheelDialogBgBottom;

  /// Top-to-bottom dialog background: near-black edges with a deep glow behind
  /// the wheel. Pair with [backgroundStops].
  ///
  /// The glow takes only its HUE from `theme.bg_color`; saturation and
  /// lightness are fixed at the reference art's values. That keeps it a deep,
  /// soft glow for any API color (a bright red would otherwise give a loud red
  /// screen, since [SpinWheelPurple.shade] offsets are relative to the base).
  static List<Color> get backgroundColors => [
    backgroundTop,
    _tinted(0.036, 0.26),
    _tinted(0.238, 0.48),
    _tinted(0.205, 0.50),
    _tinted(0.055, 0.38),
    backgroundBottom,
  ];

  static Color _tinted(double lightness, double saturation) =>
      HSLColor.fromAHSL(
        1,
        SpinWheelPurple.hue,
        saturation,
        lightness,
      ).toColor();
  static const backgroundStops = [0.0, 0.14, 0.45, 0.65, 0.88, 1.0];

  /// Dim layer behind the result card.
  static const resultScrim = AppColors.spinWheelResultScrim;

  // Title ("poster" text): outline plus the two lines' gradient fills.
  static Color get titleOutline => SpinWheelPurple.shade(-0.176, 1.04);
  static List<Color> get titleTopFill => [
    AppColors.white,
    SpinWheelPurple.shade(0.333, 1.6),
  ];
  static const titleBottomFill = [
    AppColors.spinWheelTitleBottomFillStart,
    AppColors.spinWheelTitleBottomFillEnd,
  ];
}

/// Every purple in the spin-wheel UI (board, tray, studs, result card, title
/// outline, dialog glow) comes from ONE color: [base].
///
/// [shade] keeps the base's hue and derives the rest:
///  - `dl` shifts lightness relative to [base] (+ lighter, - darker),
///  - `ks` scales saturation relative to [base] (1 = same as base).
///
/// [base] defaults to the design's purple and is replaced by the config API's
/// `campaign.theme.bg_color` via [apply], so the backend re-themes the whole
/// board without an app update. The `dl` / `ks` numbers at each call site give
/// the design its depth (highlights, edges, shadows); they were measured from
/// the reference art, so leave them alone. Read these through getters (not
/// `static final`) so a new base takes effect.
abstract final class SpinWheelPurple {
  static const defaultBase = AppColors.spinWheelPurpleDefaultBase;

  static Color _base = defaultBase;
  static HSLColor _hsl = HSLColor.fromColor(defaultBase);

  static Color get base => _base;

  /// Hue (degrees) of [base].
  static double get hue => _hsl.hue;

  /// Highlight of the lit stud beside the SPIN button — `theme.light_color`.
  /// White when the API sends none.
  static Color light = AppColors.white;

  static void apply(Color? color) {
    _base = color ?? defaultBase;
    _hsl = HSLColor.fromColor(_base);
  }

  static Color shade(double dl, [double ks = 1.0]) => _hsl
      .withSaturation((_hsl.saturation * ks).clamp(0.0, 1.0))
      .withLightness((_hsl.lightness + dl).clamp(0.0, 1.0))
      .toColor();
}

/// Every gold of the SPIN button (face gradient, lip, label, shine) comes from
/// ONE color: [base] — `campaign.theme.button_color` from the config API.
///
/// Same idea as [SpinWheelPurple], plus `dh` (hue shift, degrees) because the
/// reference art's highlights drift toward yellow and its shadows toward
/// orange. With the default base the result is the original hand-picked gold.
abstract final class SpinWheelGold {
  static const defaultBase = AppColors.spinWheelButtonGoldDefaultBase;

  static HSLColor _hsl = HSLColor.fromColor(defaultBase);

  static void apply(Color? color) {
    _hsl = HSLColor.fromColor(color ?? defaultBase);
  }

  static Color shade(double dl, [double ks = 1.0, double dh = 0]) => _hsl
      .withHue((_hsl.hue + dh) % 360)
      .withSaturation((_hsl.saturation * ks).clamp(0.0, 1.0))
      .withLightness((_hsl.lightness + dl).clamp(0.0, 1.0))
      .toColor();

  // Face gradient, top -> bottom.
  static Color get faceTop => shade(0.245, 1.078, 10.5);
  static Color get faceMid => shade(0.084, 1.078, 5);
  static Color get faceBottom => shade(0);
  // Bright edge along the top of the face.
  static Color get faceEdge => shade(0.339, 1.078, 13.5);
  // Darker lip visible under the face, top -> bottom.
  static Color get lipTop => shade(-0.067, 0.949, -7.3);
  static Color get lipBottom => shade(-0.165, 1.024, -9.1);
  // Label and its soft glow.
  static Color get label => shade(-0.194, 0.964, -18);
  static Color get labelGlow =>
      shade(0.276, 1.078, 10.9).withValues(alpha: 0.5);
}
