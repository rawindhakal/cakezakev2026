import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/password_policy.dart';
import 'package:flutter/material.dart';

extension InputValidators on String? {
  String? validateEmail(BuildContext context, {bool required = true}) {
    final val = this?.trim() ?? '';
    if (val.isEmpty) {
      return required
          ? context.translate(LanguageLabelKeys.pleaseEnterEmail)
          : null;
    }
    if (!RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
      return context.translate(LanguageLabelKeys.pleaseEnterValidEmail);
    }
    return null;
  }

  String? validateMobile(
    BuildContext context, {
    int minLength = 10,
    bool required = true,
  }) {
    final val = this?.trim() ?? '';
    if (val.isEmpty) {
      return required
          ? context.translate(LanguageLabelKeys.pleaseEnterPhoneNumber)
          : null;
    }
    if (val.length < minLength) {
      return context.translate(LanguageLabelKeys.pleaseEnterValidPhoneNumber);
    }
    return null;
  }

  String? validatePassword(BuildContext context) {
    if (this == null || this!.isEmpty) {
      return context.translate(LanguageLabelKeys.pleaseEnterPassword);
    }
    final policy = PasswordPolicy.fromSettings();
    if (!policy.isValid(context, this!)) {
      return context.translate(LanguageLabelKeys.passwordRequirementsNotMet);
    }
    return null;
  }

  String? validateRequiredField(BuildContext context, {String? message}) {
    if (this == null || this!.trim().isEmpty) {
      return message ?? context.translate(LanguageLabelKeys.required);
    }
    return null;
  }

  String? validateNewPassword(BuildContext context) {
    if (this == null || this!.isEmpty) {
      return context.translate(LanguageLabelKeys.pleaseEnterPassword);
    }
    final policy = PasswordPolicy.fromSettings();
    if (!policy.isValid(context, this!)) {
      return context.translate(LanguageLabelKeys.passwordRequirementsNotMet);
    }
    return null;
  }

  String? validateConfirmPassword(BuildContext context, String password) {
    if (this == null || this!.isEmpty) {
      return context.translate(LanguageLabelKeys.pleaseConfirmPassword);
    }
    if (this != password) {
      return context.translate(LanguageLabelKeys.passwordsDoNotMatch);
    }
    return null;
  }

  String? validateName(BuildContext context) {
    if (this == null || this!.trim().isEmpty) {
      return context.translate(LanguageLabelKeys.pleaseEnterName);
    }
    if (this!.trim().length < 2) {
      return context.translate(LanguageLabelKeys.nameMinLength);
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
