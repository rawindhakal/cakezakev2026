import 'dart:io';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import '../../../commons/widgets/app_image_upload_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../commons/widgets/app_text.dart';

/// Upload section for national ID and driving license images during registration.
class IdentityDocsSection extends StatelessWidget {
  final File? nationalIdImage;
  final String? nationalIdError;
  final ValueChanged<File> onNationalIdPicked;
  final File? drivingLicenseImage;
  final String? drivingLicenseError;
  final ValueChanged<File> onDrivingLicensePicked;

  const IdentityDocsSection({
    super.key,
    required this.nationalIdImage,
    required this.nationalIdError,
    required this.onNationalIdPicked,
    required this.drivingLicenseImage,
    required this.drivingLicenseError,
    required this.onDrivingLicensePicked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        _label(context, context.translate(LanguageLabelKeys.nationalIdImage)),
        AppSpacing.h8,
        AppImageUploadField(
          label: context.translate(LanguageLabelKeys.nationalId),
          image: nationalIdImage,
          errorText: nationalIdError,
          onPicked: onNationalIdPicked,
        ),
        if (nationalIdError != null) ...[
          AppSpacing.h4,
          AppText(
            nationalIdError!,
            style: context.tt.bodySmall?.copyWith(color: context.cs.error),
          ),
        ],
        AppSpacing.h14,

        _label(
          context,
          context.translate(LanguageLabelKeys.drivingLicenseImage),
        ),
        AppSpacing.h8,
        AppImageUploadField(
          label: context.translate(LanguageLabelKeys.drivingLicense),
          image: drivingLicenseImage,
          errorText: drivingLicenseError,
          onPicked: onDrivingLicensePicked,
        ),
        if (drivingLicenseError != null) ...[
          AppSpacing.h4,
          AppText(
            drivingLicenseError!,
            style: context.tt.bodySmall?.copyWith(color: context.cs.error),
          ),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, String text) {
    return AppText(
      text,
      style: context.tt.labelMedium?.copyWith(color: context.cs.onSurface),
      isRequired: true,
    );
  }
}
