import 'package:deliveryboy/commons/utils/app_haptics.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Enum for snackbar types
enum SnackBarType { success, error, warning, info }

/// Custom SnackBar widget for consistent app notifications
class AppSnackBar {
  /// Show a snackbar with custom styling
  ///
  /// [context] - BuildContext for showing the snackbar
  /// [message] - The message to display
  /// [type] - Type of snackbar (success, error, warning, info)
  /// [duration] - How long to show the snackbar (default: 3 seconds)
  /// [actionLabel] - Optional action button label
  /// [onAction] - Callback when action button is pressed
  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    switch (type) {
      case SnackBarType.success:
        AppHaptics.success();
      case SnackBarType.error:
        AppHaptics.error();
      case SnackBarType.warning:
        AppHaptics.warning();
      case SnackBarType.info:
        break;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          spacing: ThemeConstants.spaceM,
          children: [
            _getIcon(context, type),
            Expanded(
              child: AppText(
                message,
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.cs.onPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _getBackgroundColor(context, type),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r10),
        margin: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: context.cs.onPrimary,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Get icon based on snackbar type
  static Widget _getIcon(BuildContext context, SnackBarType type) {
    String icon;
    switch (type) {
      case SnackBarType.success:
        icon = AssetsConstants.checkCircleIcon;
        break;
      case SnackBarType.error:
        icon = AssetsConstants.infoCircleIcon;
        break;
      case SnackBarType.warning:
        icon = AssetsConstants.dangerIcon;
        break;
      case SnackBarType.info:
        icon = AssetsConstants.infoCircleIcon;
        break;
    }
    return AppSvgIcon(
      icon,
      color: context.cs.onPrimary,
      size: ThemeConstants.iconM,
    );
  }

  /// Get background color based on snackbar type
  static Color _getBackgroundColor(BuildContext context, SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return context.cs.onSecondaryContainer;
      case SnackBarType.error:
        return context.cs.error;
      case SnackBarType.warning:
        return context.cs.errorContainer;
      case SnackBarType.info:
        return context.cs.inversePrimary;
    }
  }
}
