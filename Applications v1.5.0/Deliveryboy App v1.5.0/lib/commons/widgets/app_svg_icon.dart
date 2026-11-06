import 'package:deliveryboy/core/theme/app_colors.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Maps the hardcoded SVG primary placeholder color to a dynamic [targetColor].
/// Use this for multi-color illustrations so only the primary accent adapts.
class AppSvgColorMapper extends ColorMapper {
  const AppSvgColorMapper(
    this.targetColor,
    this.borderColor, {
    this.surfaceColor,
    this.textStrongColor,
    this.divider2Color,
    this.bottomNavBlackColor,
    this.bottomNavLightGrayColor,
    this.bottomNavConstantColor,
    this.bottomNavPrimaryOpacity,
    this.bottomNavPrimaryShadeOpacity,
  });
  final Color targetColor;
  final Color borderColor;
  final Color? surfaceColor;
  final Color? textStrongColor;
  final Color? divider2Color;

  /// Bottom nav bar icon roles ("Bottom Nav Bar" color group). The
  /// icons bake in literal black/#444444/#333333/#E1E1E1/white/FE3C5E-with
  /// -opacity fills; these swap them for the active/inactive Black, Light
  /// Gray, Constant, Primary, and Primary Shade tokens for the current theme.
  final Color? bottomNavBlackColor;
  final Color? bottomNavLightGrayColor;
  final Color? bottomNavConstantColor;
  final double? bottomNavPrimaryOpacity;
  final double? bottomNavPrimaryShadeOpacity;

  static const _primaryGreen = Color(0xFFFE3C5E);
  static const _lightGrayFill = Color(0xFFE1E1E1);
  static const _activeBlackFill = Color(0xFF444444);
  static const _inactiveBlackFill = Color(0xFF333333);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    // Bottom nav "Primary Shade" role: baked as #FE3C5E with reduced
    // fill-opacity in the SVG. Checked before the generic placeholder swap
    // below since svgPrimaryPlaceholder may equal this same baked color.
    if (bottomNavPrimaryShadeOpacity != null &&
        color.r == _primaryGreen.r &&
        color.g == _primaryGreen.g &&
        color.b == _primaryGreen.b &&
        color.a < 1.0) {
      return targetColor.withValues(alpha: bottomNavPrimaryShadeOpacity!);
    }

    // Bottom nav "Primary" role: baked as solid #FE3C5E in the SVG (dark
    // mode dims this to 18% alpha per the design tokens; light mode is 100%).
    // Checked before the generic placeholder swap below for the same reason.
    if (bottomNavPrimaryOpacity != null &&
        color.r == _primaryGreen.r &&
        color.g == _primaryGreen.g &&
        color.b == _primaryGreen.b &&
        color.a == 1.0) {
      return targetColor.withValues(alpha: bottomNavPrimaryOpacity!);
    }

    // Replace your placeholder color
    if (color == AppColors.svgPrimaryPlaceholder) {
      return targetColor;
    }

    // Bottom nav "Constant" role: baked as literal white in the SVG.
    if (bottomNavConstantColor != null && color == Colors.white) {
      return bottomNavConstantColor!;
    }

    // Bottom nav "Black" role: stroke baked as literal black, or already
    // resolved to the light-mode #444444 (active) / #333333 (inactive) value.
    if (bottomNavBlackColor != null &&
        (color == AppColors.black ||
            color == _activeBlackFill ||
            color == _inactiveBlackFill)) {
      return bottomNavBlackColor!;
    }

    // Bottom nav "Light Gray" role: inactive icon fill baked as #E1E1E1.
    if (bottomNavLightGrayColor != null && color == _lightGrayFill) {
      return bottomNavLightGrayColor!;
    }

    // SVGs authored with the light-mode token values baked in as literal
    // fills (black stroke == textStrong's mode1/light value); swap for the
    // current theme's resolved value (mode2/dark when theme is dark).
    if (textStrongColor != null &&
        (color == AppColors.black || color == AppColors.textStrong)) {
      return textStrongColor!;
    }
    if (color == AppColors.iconBorder) {
      return borderColor;
    }
    if (surfaceColor != null && color == AppColors.white) {
      return surfaceColor!;
    }
    if (divider2Color != null && color == AppColors.divider2) {
      return divider2Color!;
    }

    return color;
  }
}

/// Renders a bundled SVG asset, optionally recolored via [color] or [useColorMapper].
class AppSvgIcon extends StatelessWidget {
  final String path;

  /// Explicit square size. Null = unconstrained (fills parent or natural size).
  final double? size;

  /// Flat tint — replaces ALL colors with [color] via [ColorFilter].
  final Color? color;

  /// When true, maps the SVG's primary placeholder color to [color] while
  /// keeping all other colors intact. Requires [color] to be non-null.
  final bool useColorMapper;

  final BoxFit fit;

  final WidgetBuilder? placeholderBuilder;

  /// Overrides the default [AppSvgColorMapper] when set — use for icons with
  /// their own bespoke role-based palette (e.g. bottom nav icons).
  final ColorMapper? colorMapper;

  const AppSvgIcon(
    this.path, {
    super.key,
    this.size,
    this.color,
    this.useColorMapper = false,
    this.fit = .contain,
    this.placeholderBuilder,
    this.colorMapper,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      fit: fit,
      colorMapper:
          colorMapper ??
          (useColorMapper && color != null
              ? AppSvgColorMapper(
                  color!,
                  context.cs.outline,
                  surfaceColor: context.cs.surface,
                  textStrongColor: context.cs.onSurface,
                  divider2Color: context.cs.outlineVariant,
                )
              : null),
      colorFilter: !useColorMapper && color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
      placeholderBuilder: placeholderBuilder,
    );
  }
}
