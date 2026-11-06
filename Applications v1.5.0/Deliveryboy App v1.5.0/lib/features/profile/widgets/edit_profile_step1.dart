import 'dart:io';

import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/models/earning_type.dart';
import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/country_dropdown_field.dart';
import 'package:deliveryboy/commons/widgets/country_phone_field.dart';
import 'package:deliveryboy/commons/widgets/zone_dropdown_field.dart';
import 'package:deliveryboy/commons/widgets/earning_type_selector.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../commons/widgets/app_text_field.dart';
import '../../../commons/widgets/app_image_upload_field.dart';

import 'package:deliveryboy/core/theme/app_spacing.dart';

import '../../../utils/input_validators.dart';
import '../../../commons/widgets/app_text.dart';

/// Step 1 of edit profile: personal info, documents, and earning type.
class EditProfileStep1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final bool emailReadOnly;
  final TextEditingController dobController;
  final TextEditingController mobileController;
  final TextEditingController addressController;
  final TextEditingController commissionController;
  final TextEditingController bonusMinController;
  final TextEditingController bonusMaxController;
  final TextEditingController returnCommissionController;
  final TextEditingController returnBonusMinController;
  final TextEditingController returnBonusMaxController;
  final EarningType returnEarningType;
  final File? nationalIdImage;
  final String? nationalIdImageUrl;
  final File? drivingLicenseImage;
  final String? drivingLicenseImageUrl;
  final String? nationalIdError;
  final String? drivingLicenseError;
  final EarningType earningType;
  final CountriesData? selectedCountry;
  final ZonesData? selectedZone;
  final ValueChanged<ZonesData> onZoneChanged;
  final String? Function(String?)? zoneValidator;
  final ValueChanged<EarningType> onEarningTypeChanged;
  final ValueChanged<File> onNationalIdPicked;
  final ValueChanged<File> onDrivingLicensePicked;
  final VoidCallback onPickDob;

  const EditProfileStep1({
    super.key,
    required this.formKey,
    required this.usernameController,
    required this.emailController,
    this.emailReadOnly = false,
    required this.dobController,
    required this.mobileController,
    required this.addressController,
    required this.commissionController,
    required this.bonusMinController,
    required this.bonusMaxController,
    required this.returnCommissionController,
    required this.returnBonusMinController,
    required this.returnBonusMaxController,
    required this.returnEarningType,
    required this.nationalIdImage,
    required this.nationalIdImageUrl,
    required this.drivingLicenseImage,
    required this.drivingLicenseImageUrl,
    required this.nationalIdError,
    required this.drivingLicenseError,
    required this.earningType,
    required this.selectedCountry,
    required this.selectedZone,
    required this.onZoneChanged,
    this.zoneValidator,
    required this.onEarningTypeChanged,
    required this.onNationalIdPicked,
    required this.onDrivingLicensePicked,
    required this.onPickDob,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingS,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingL,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: .start,
          children: [
            _label(context, context.translate(LanguageLabelKeys.fullName)),
            AppSpacing.h8,
            AppTextField(
              controller: usernameController,
              hintText: context.translate(LanguageLabelKeys.enterFullName),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v.validateRequired(context, context.translate(LanguageLabelKeys.fullName)),
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.email)),
            AppSpacing.h8,
            AppTextField(
              controller: emailController,
              hintText: context.translate(LanguageLabelKeys.enterEmail),
              keyboardType: TextInputType.emailAddress,
              readOnly: emailReadOnly,
              validator: (v) => v.validateEmail(context, required: false),
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.dateOfBirth)),
            AppSpacing.h8,
            AppTextField(
              controller: dobController,
              hintText: context.translate(LanguageLabelKeys.enterDob),
              readOnly: true,
              onTap: onPickDob,
              suffixIcon: AppSvgIcon(AssetsConstants.dateIcon, size: ThemeConstants.iconL, color: context.cs.onSurfaceVariant, fit: BoxFit.scaleDown),
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.country)),
            AppSpacing.h8,
            CountryDropdownField(
              selected: selectedCountry,
              labelText: '',
              hintText: context.translate(LanguageLabelKeys.selectCountry),
              onChanged: (_) {},
              readOnly: true,
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.zone)),
            AppSpacing.h8,
            ZoneDropdownField(
              selected: selectedZone,
              labelText: '',
              hintText: context.translate(LanguageLabelKeys.selectZone),
              onChanged: onZoneChanged,
              validator: zoneValidator,
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.mobileNumber)),
            AppSpacing.h8,
            ApiCountryPhoneField(
              controller: mobileController,
              selectedCountry: selectedCountry,
              onCountryChanged: (_) {},
              countryReadOnly: true,
              hintText: context.translate(LanguageLabelKeys.mobileNumber),
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.nationalIdImage)),
            AppSpacing.h8,
            AppImageUploadField(
              label: context.translate(LanguageLabelKeys.nationalId),
              image: nationalIdImage,
              imageUrl: nationalIdImageUrl,
              errorText: nationalIdError,
              onPicked: onNationalIdPicked,
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.drivingLicenseImage)),
            AppSpacing.h8,
            AppImageUploadField(
              label: context.translate(LanguageLabelKeys.drivingLicense),
              image: drivingLicenseImage,
              imageUrl: drivingLicenseImageUrl,
              errorText: drivingLicenseError,
              onPicked: onDrivingLicensePicked,
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.address)),
            AppSpacing.h8,
            AppTextField(
              controller: addressController,
              hintText: context.translate(LanguageLabelKeys.enterAddress),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              validator: (v) => v.validateRequired(context, context.translate(LanguageLabelKeys.address)),
            ),
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.earningType)),
            AppSpacing.h8,
            EarningTypeSelector(
              value: earningType,
              onChanged: (v) {
                if (v != null) onEarningTypeChanged(v);
              },
              enabled: false,
            ),
            if (earningType == EarningType.commission) ...[
              AppSpacing.h14,
              _label(context, context.translate(LanguageLabelKeys.commissionPercent)),
              AppSpacing.h8,
              AppTextField(
                controller: commissionController,
                hintText: context.translate(LanguageLabelKeys.enterCommission),
                keyboardType: TextInputType.number,
                readOnly: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => earningType == EarningType.commission ? v.validateCommission(context) : null,
              ),
              AppSpacing.h14,
              _MinMaxRow(minController: bonusMinController, maxController: bonusMaxController),
            ],
            AppSpacing.h14,
            _label(context, context.translate(LanguageLabelKeys.returnEarningType)),
            AppSpacing.h8,
            EarningTypeSelector(value: returnEarningType, onChanged: (_) {}, enabled: false),
            if (returnEarningType == EarningType.commission) ...[
              AppSpacing.h14,
              _label(context, context.translate(LanguageLabelKeys.returnCommissionPercent)),
              AppSpacing.h8,
              AppTextField(
                controller: returnCommissionController,
                hintText: context.translate(LanguageLabelKeys.enterCommission),
                keyboardType: TextInputType.number,
                readOnly: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              AppSpacing.h14,
              _MinMaxRow(minController: returnBonusMinController, maxController: returnBonusMaxController),
            ],
            AppSpacing.h8,
          ],
        ),
      ),
    );
  }
}

Widget _label(BuildContext context, String text) {
  return AppText(text, style: context.tt.labelMedium?.copyWith(color: context.cs.onSurface));
}

/// Read-only min/max bonus-amount pair shown under a commission block.
class _MinMaxRow extends StatelessWidget {
  final TextEditingController minController;
  final TextEditingController maxController;

  const _MinMaxRow({required this.minController, required this.maxController});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _label(context, context.translate(LanguageLabelKeys.minAmount)),
              AppSpacing.h8,
              AppTextField(
                controller: minController,
                keyboardType: TextInputType.number,
                readOnly: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        AppSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _label(context, context.translate(LanguageLabelKeys.maxAmount)),
              AppSpacing.h8,
              AppTextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                readOnly: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
