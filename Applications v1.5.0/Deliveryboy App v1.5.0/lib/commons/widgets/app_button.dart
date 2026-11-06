import 'package:deliveryboy/commons/widgets/loading_widget.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Visual style of [AppButton].
enum AppButtonVariant { primary, secondary, danger, outline, text }

/// Standard app button with a loading spinner state and consistent variant styling.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final double? width;
  final double height;
  final Widget? prefixIcon;
  final Color? color;
  final bool contentLeftAlign;

  /// Overrides the button's fill color (primary/secondary/danger variants).
  final Color? backgroundColor;

  /// Overrides the default corner radius — e.g. a pill shape for dialogs.
  final BorderRadius? borderRadius;

  /// Overrides the label's font size (defaults to titleSmall's size).
  final double? fontSize;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.height = 52,
    this.prefixIcon,
    this.color,
    this.contentLeftAlign = false,
    this.backgroundColor,
    this.borderRadius,
    this.fontSize,
  });

  static const _radius = AppRadius.r10;

  @override
  Widget build(BuildContext context) {
    if (variant == AppButtonVariant.text) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsetsDirectional.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: isLoading
            ? LoadingWidget(size: ThemeConstants.loaderSizeS)
            : _child(context, color ?? context.cs.primary),
      );
    }
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: switch (variant) {
        AppButtonVariant.outline => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: color ?? context.cs.primary,
            side: BorderSide(color: color ?? context.cs.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? _radius,
            ),
            alignment: contentLeftAlign
                ? AlignmentDirectional.centerStart
                : Alignment.center,
            padding: contentLeftAlign
                ? const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingM,
                  )
                : EdgeInsetsDirectional.zero,
          ),
          child: _child(context, color ?? context.cs.primary),
        ),
        AppButtonVariant.danger => FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor ?? context.cs.error,
            foregroundColor: context.cs.onError,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? _radius,
            ),
            padding: EdgeInsetsDirectional.zero,
            elevation: 0,
          ),
          child: _child(context, context.cs.onError),
        ),
        AppButtonVariant.secondary => FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor ?? context.cs.primaryContainer,
            foregroundColor: color ?? context.cs.primary,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? _radius,
            ),
            padding: EdgeInsetsDirectional.zero,
            elevation: 0,
          ),
          child: _child(context, color ?? context.cs.primary),
        ),
        _ => FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor ?? context.cs.primary,
            foregroundColor: context.cs.onPrimary,
            disabledBackgroundColor: context.cs.primary.withValues(alpha: 0.6),
            disabledForegroundColor: context.cs.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? _radius,
            ),
            padding: EdgeInsetsDirectional.zero,
            elevation: 0,
          ),
          child: _child(context, context.cs.onPrimary),
        ),
      },
    );
  }

  Widget _child(BuildContext context, Color color) {
    if (isLoading) {
      return LoadingWidget(size: ThemeConstants.loaderSize);
    }
    if (prefixIcon != null) {
      return Row(
        mainAxisAlignment: contentLeftAlign ? .start : .center,
        spacing: ThemeConstants.spaceS,
        children: [
          prefixIcon!,
          contentLeftAlign
              ? Expanded(
                  child: AppText(
                    label,
                    overflow: .ellipsis,
                    style: context.tt.titleSmall?.copyWith(
                      color: color,
                      fontSize: fontSize,
                    ),
                  ),
                )
              : AppText(
                  label,
                  style: context.tt.titleSmall?.copyWith(
                    color: color,
                    fontSize: fontSize,
                  ),
                ),
        ],
      );
    }
    return AppText(
      label,
      style: context.tt.titleSmall?.copyWith(color: color, fontSize: fontSize),
    );
  }
}
