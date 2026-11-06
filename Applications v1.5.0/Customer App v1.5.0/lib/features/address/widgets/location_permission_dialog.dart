import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/widgets/app_confirm_dialog.dart';

Future<void> showLocationPermissionDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AppConfirmDialog(
      iconGlyph: AssetsConstants.locationOffIcon,
      iconColor: ctx.cs.primary,
      title: ctx.translate(LanguageLabelKeys.locationPermissionTitle),
      message: ctx.translate(LanguageLabelKeys.locationPermissionMessage),
      cancelLabel: ctx.translate(LanguageLabelKeys.cancel),
      confirmLabel: ctx.translate(LanguageLabelKeys.goToSettings),
      onCancel: () => AppNavigator.pop(ctx),
      onConfirm: () {
        AppNavigator.pop(ctx);
        Geolocator.openAppSettings();
      },
    ),
  );
}
