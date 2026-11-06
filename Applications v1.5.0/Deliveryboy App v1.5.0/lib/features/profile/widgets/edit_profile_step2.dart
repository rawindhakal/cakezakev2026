import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../commons/widgets/app_text_field.dart';

import 'package:deliveryboy/core/theme/app_spacing.dart';

import '../../../utils/input_validators.dart';

import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Step 2 of edit profile: bank account details.
class EditProfileStep2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController bankNameController;
  final TextEditingController accountNumberController;
  final TextEditingController ifscCodeController;
  final TextEditingController accountNameController;
  final bool bankNameReadOnly;
  final bool accountNumberReadOnly;
  final bool ifscCodeReadOnly;
  final bool accountNameReadOnly;

  const EditProfileStep2({
    super.key,
    required this.formKey,
    required this.bankNameController,
    required this.accountNumberController,
    required this.ifscCodeController,
    required this.accountNameController,
    this.bankNameReadOnly = false,
    this.accountNumberReadOnly = false,
    this.ifscCodeReadOnly = false,
    this.accountNameReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
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
              _label(context, context.translate(LanguageLabelKeys.bankName)),
              AppSpacing.h8,
              AppTextField(
                controller: bankNameController,
                hintText: context.translate(LanguageLabelKeys.enterBankName),
                textCapitalization: TextCapitalization.words,
                readOnly: bankNameReadOnly,
                validator: (v) => v.validateRequired(context, context.translate(LanguageLabelKeys.bankName)),
              ),
              AppSpacing.h14,
              _label(context, context.translate(LanguageLabelKeys.accountNumber)),
              AppSpacing.h8,
              AppTextField(
                controller: accountNumberController,
                hintText: context.translate(LanguageLabelKeys.enterAccountNumber),
                keyboardType: TextInputType.number,
                readOnly: accountNumberReadOnly,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v.validateRequired(context, context.translate(LanguageLabelKeys.accountNumber)),
              ),
              AppSpacing.h14,
              _label(context, context.translate(LanguageLabelKeys.ifscCode)),
              AppSpacing.h8,
              AppTextField(
                controller: ifscCodeController,
                hintText: context.translate(LanguageLabelKeys.enterIfscCode),
                textCapitalization: TextCapitalization.characters,
                readOnly: ifscCodeReadOnly,
                validator: (v) => v.validateRequired(context, context.translate(LanguageLabelKeys.ifscCode)),
              ),
              AppSpacing.h14,
              _label(context, context.translate(LanguageLabelKeys.accountHolderName)),
              AppSpacing.h8,
              AppTextField(
                controller: accountNameController,
                hintText: context.translate(LanguageLabelKeys.enterAccountHolderName),
                textCapitalization: TextCapitalization.words,
                readOnly: accountNameReadOnly,
                validator: (v) => v.validateRequired(context, context.translate(LanguageLabelKeys.accountHolderName)),
              ),
              AppSpacing.h8,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _label(BuildContext context, String text) {
  return AppText(text, style: context.tt.labelMedium?.copyWith(color: context.cs.onSurface));
}
