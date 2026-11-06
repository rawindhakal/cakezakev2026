import 'package:flutter/material.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import '../core/localization/language_label_key.dart';
import 'password_policy.dart';

extension InputValidators on String? {
  String? validateRequired(BuildContext context, String fieldName) {
    if (this == null || this!.trim().isEmpty) {
      return context
          .translate(LanguageLabelKeys.fieldRequired)
          .replaceAll('{field}', fieldName);
    }
    return null;
  }

  String? validateEmail(BuildContext context, {bool required = true}) {
    final val = this?.trim() ?? '';
    if (val.isEmpty) {
      return required
          ? context.translate(LanguageLabelKeys.emailRequired)
          : null;
    }
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
      return context.translate(LanguageLabelKeys.enterValidEmail);
    }
    return null;
  }

  String? validateMobile(BuildContext context, {int minLength = 10}) {
    final val = this?.trim() ?? '';
    if (val.isEmpty) return context.translate(LanguageLabelKeys.mobileRequired);
    if (val.length < minLength) {
      return context.translate(LanguageLabelKeys.enterValidMobile);
    }
    return null;
  }

  String? validatePassword(BuildContext context) {
    if (this == null || this!.isEmpty) {
      return context.translate(LanguageLabelKeys.passwordRequired);
    }
    final policy = PasswordPolicy.fromSettings();
    if (!policy.isValid(context, this!)) {
      return context.translate(LanguageLabelKeys.passwordRequirementsNotMet);
    }
    return null;
  }

  String? validateConfirmPassword(BuildContext context, String password) {
    if (this == null || this!.isEmpty) {
      return context.translate(LanguageLabelKeys.confirmPasswordRequired);
    }
    if (this != password) {
      return context.translate(LanguageLabelKeys.passwordsDoNotMatch);
    }
    return null;
  }

  String? validateCommission(BuildContext context) {
    final val = this?.trim() ?? '';
    if (val.isEmpty) {
      return context.translate(LanguageLabelKeys.commissionRequired);
    }
    final num = int.tryParse(val);
    if (num == null || num <= 0 || num > 100) {
      return context.translate(LanguageLabelKeys.enterValidPercentage);
    }
    return null;
  }
}
