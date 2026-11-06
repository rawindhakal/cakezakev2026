import 'package:flutter/material.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Minimal sheet title row — no close button (dismiss via drag handle /
/// outside tap like the rest of the sheet).
class SheetHeader extends StatelessWidget {
  final bool isEdit;

  const SheetHeader({super.key, required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingS,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
      ),
      child: AppText(
        isEdit
            ? context.translate(LanguageLabelKeys.editAddress)
            : context.translate(LanguageLabelKeys.addAddress),
        style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
