import 'package:customer/commons/utils/app_haptics.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Shows a small animated checkmark dialog that auto-dismisses once the
/// Lottie animation finishes playing (plus a short hold so the message is
/// readable) — used for quick success confirmations that don't need a full
/// success screen (e.g. rating submitted).
Future<void> showAppSuccessDialog(
  BuildContext context, {
  required String message,
  Duration extraHold = const Duration(milliseconds: 500),
}) {
  AppHaptics.success();
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppSuccessDialog(message: message, extraHold: extraHold),
  );
}

class _AppSuccessDialog extends StatefulWidget {
  final String message;
  final Duration extraHold;
  const _AppSuccessDialog({required this.message, required this.extraHold});

  @override
  State<_AppSuccessDialog> createState() => _AppSuccessDialogState();
}

class _AppSuccessDialogState extends State<_AppSuccessDialog> {
  void _onLoaded(LottieComposition composition) {
    Future.delayed(composition.duration + widget.extraHold, () {
      if (mounted) AppNavigator.of(context, rootNavigator: true).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingXXL,
          vertical: ThemeConstants.paddingXL,
        ),
        child: Column(
          mainAxisSize: .min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.asset(
                AssetsConstants.successCircleCheck,
                repeat: false,
                onLoaded: _onLoaded,
              ),
            ),
            AppSpacing.h8,
            AppText(
              widget.message,
              textAlign: .center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
