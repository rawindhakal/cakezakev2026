import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';

enum AppButtonVariant { primary, secondary, danger, outline }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final double? width;
  final double height;
  final Widget? prefixIcon;

  /// When false, the button shrinks to its content instead of filling the
  /// available width — use for compact/chip-style actions (e.g. Track,
  /// Cancel) placed inside a Row.
  final bool fullWidth;

  /// Overrides the variant's default accent color (foreground/border for
  /// [AppButtonVariant.outline]). Leave null to use the theme's primary.
  final Color? color;

  /// Overrides the button's fill color. For [AppButtonVariant.outline] this
  /// is transparent by default; set it to give an outlined button a fill
  /// (e.g. a white background behind a social-sign-in button).
  final Color? backgroundColor;

  /// Overrides the outline border color for [AppButtonVariant.outline].
  /// Leave null to reuse [color] (foreground) as the border color.
  final Color? borderColor;

  /// Overrides the label's font size. Leave null to use labelLarge's default.
  final double? fontSize;

  final EdgeInsetsGeometry? contentPadding;

  /// Overrides the default corner radius ([AppRadius.r10]) — e.g. a pill
  /// shape for compact icon+label chips.
  final BorderRadius? borderRadius;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.height = 52,
    this.prefixIcon,
    this.fullWidth = true,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.fontSize,
    this.contentPadding,
    this.borderRadius,
  });

  static const _radius = AppRadius.r10;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final button = switch (variant) {
      AppButtonVariant.outline => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: color ?? colorScheme.primary,
          side: BorderSide(
            color: borderColor ?? color ?? colorScheme.primary,
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadius ?? _radius),
          padding: contentPadding ?? EdgeInsetsDirectional.zero,
          minimumSize: fullWidth ? null : Size(0, height),
          tapTargetSize: fullWidth ? null : MaterialTapTargetSize.shrinkWrap,
        ),
        child: _child(context, color ?? colorScheme.primary),
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? colorScheme.error,
          foregroundColor: colorScheme.onError,
          shape: RoundedRectangleBorder(borderRadius: borderRadius ?? _radius),
          padding: contentPadding ?? EdgeInsetsDirectional.zero,
          minimumSize: fullWidth ? null : Size(0, height),
          tapTargetSize: fullWidth ? null : MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
        ),
        child: _child(context, colorScheme.onError),
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? colorScheme.primaryContainer,
          foregroundColor: color ?? colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: borderRadius ?? _radius),
          padding: contentPadding ?? EdgeInsetsDirectional.zero,
          minimumSize: fullWidth ? null : Size(0, height),
          tapTargetSize: fullWidth ? null : MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
        ),
        child: _child(context, color ?? colorScheme.primary),
      ),
      _ => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: (color ?? colorScheme.primary).withValues(
            alpha: 0.6,
          ),
          disabledForegroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: borderRadius ?? _radius),
          padding: contentPadding ?? EdgeInsetsDirectional.zero,
          minimumSize: fullWidth ? null : Size(0, height),
          tapTargetSize: fullWidth ? null : MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
        ),
        child: _child(context, colorScheme.onPrimary),
      ),
    };

    return SizedBox(
      width: fullWidth ? (width ?? double.infinity) : width,
      height: height,
      child: button,
    );
  }

  Widget _child(BuildContext context, Color color) {
    if (isLoading) {
      return LoadingWidget(size: ThemeConstants.loaderSize);
    }
    final labelText = AppText(
      label,
      style: context.tt.labelLarge?.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
    if (prefixIcon != null) {
      return Row(
        mainAxisAlignment: .center,
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        spacing: ThemeConstants.spaceS,
        children: [
          IconTheme.merge(
            data: IconThemeData(color: color),
            child: prefixIcon!,
          ),
          labelText,
        ],
      );
    }
    return labelText;
  }
}
