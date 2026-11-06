import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_palette.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Two-line "poster" title above the wheel.
///
/// The first word sits on a small pale-lavender top line and the remaining
/// words on a larger cream-gold second line ("Daily" / "Reward"). A
/// one-word title shows as a single large line.
///
/// [title] is the campaign name from the config API; when it is null or empty
/// the translated "Spin & Win" is used instead.
class SpinWheelTitle extends StatelessWidget {
  final String? title;

  /// `theme.title_color`: first line's outline, and (as a lighter tint) its
  /// fill. `theme.title_color_2`: second line's outline and fill, as-is.
  /// Null keeps the default palette.
  final Color? topColor;
  final Color? bottomColor;

  const SpinWheelTitle({
    super.key,
    this.title,
    this.topColor,
    this.bottomColor,
  });

  // Fill: a lighter tint of the same outline color, so the letters read
  // clearly against their full-strength outline instead of blending into it.
  static List<Color> _fill(Color c) => [
    Color.lerp(c, AppColors.white, 0.7)!,
    Color.lerp(c, AppColors.white, 0.5)!,
  ];

  static const _topFontSize = 40.0;
  static const _bottomFontSize = 46.0;

  /// The second line tucks up under the first by this much (paint only).
  static const _lineOverlap = 8.0;

  /// The whole title is shifted down (paint only, no layout change) so its
  /// second line sits just above the wheel's pin, as in the reference.
  static const _shiftDown = 24.0;

  @override
  Widget build(BuildContext context) {
    final text = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : context.translate(LanguageLabelKeys.spinAndWin);
    final words = text.split(RegExp(r'\s+'));
    final hasTopLine = words.length > 1;
    final bottomText = hasTopLine ? words.skip(1).join(' ') : text;

    return Transform.translate(
      offset: const Offset(0, _shiftDown),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTopLine)
            _PosterText(
              words.first,
              fontSize: _topFontSize,
              outline: topColor,
              fill: topColor != null
                  ? _fill(topColor!)
                  : SpinWheelPalette.titleTopFill,
            ),
          Transform.translate(
            offset: Offset(0, hasTopLine ? -_lineOverlap : 0),
            child: _PosterText(
              bottomText,
              fontSize: _bottomFontSize,
              outline: bottomColor,
              fill: bottomColor != null
                  ? _fill(bottomColor!)
                  : SpinWheelPalette.titleBottomFill,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bold italic serif text (Playfair Display) with a vertical gradient fill,
/// a purple outline and a soft drop shadow.
///
/// Drawn as two stacked [Text]s: a stroked copy underneath for the outline
/// and shadow, and the gradient-filled copy on top.
class _PosterText extends StatelessWidget {
  final String text;
  final double fontSize;

  /// Top-to-bottom gradient colors of the letters.
  final List<Color> fill;

  /// Outline color; null → the default purple.
  final Color? outline;

  const _PosterText(
    this.text, {
    required this.fontSize,
    required this.fill,
    this.outline,
  });

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1.0,
      letterSpacing: -0.5,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeJoin = StrokeJoin.round
              ..color = outline ?? SpinWheelPalette.titleOutline,
            shadows: const [
              Shadow(
                color: AppColors.spinWheelTitleShadow,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: fill,
              ).createShader(Rect.fromLTWH(0, 0, 10, fontSize)),
          ),
        ),
      ],
    );
  }
}
