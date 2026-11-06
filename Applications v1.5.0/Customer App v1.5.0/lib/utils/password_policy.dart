import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

class PasswordRule {
  final String label;
  final bool satisfied;

  const PasswordRule({required this.label, required this.satisfied});
}

class PasswordPolicy {
  final int minLength;
  final int maxLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireNumber;
  final bool requireSpecial;

  const PasswordPolicy({
    required this.minLength,
    required this.maxLength,
    required this.requireUppercase,
    required this.requireLowercase,
    required this.requireNumber,
    required this.requireSpecial,
  });

  factory PasswordPolicy.fromSettings() {
    final settings = SettingsHiveBox.instance.getAppSettings();
    bool isOn(String? v) => v == '1' || v?.toLowerCase() == 'true';

    return PasswordPolicy(
      minLength: int.tryParse(settings?.passwordMinLength ?? '') ?? 5,
      maxLength: int.tryParse(settings?.passwordMaxLength ?? '') ?? 0,
      requireUppercase: isOn(settings?.passwordRequireUppercase),
      requireLowercase: isOn(settings?.passwordRequireLowercase),
      requireNumber: isOn(settings?.passwordRequireNumber),
      requireSpecial: isOn(settings?.passwordRequireSpecial),
    );
  }

  List<PasswordRule> evaluate(BuildContext context, String value) {
    final rules = <PasswordRule>[
      PasswordRule(
        label: context
            .translate(LanguageLabelKeys.passwordRuleMinLength)
            .replaceAll('{min}', minLength.toString()),
        satisfied: value.length >= minLength,
      ),
    ];

    if (maxLength > 0) {
      rules.add(
        PasswordRule(
          label: context
              .translate(LanguageLabelKeys.passwordRuleMaxLength)
              .replaceAll('{max}', maxLength.toString()),
          satisfied: value.isNotEmpty && value.length <= maxLength,
        ),
      );
    }

    if (requireUppercase) {
      rules.add(
        PasswordRule(
          label: context.translate(LanguageLabelKeys.passwordRuleUppercase),
          satisfied: RegExp(r'[A-Z]').hasMatch(value),
        ),
      );
    }

    if (requireLowercase) {
      rules.add(
        PasswordRule(
          label: context.translate(LanguageLabelKeys.passwordRuleLowercase),
          satisfied: RegExp(r'[a-z]').hasMatch(value),
        ),
      );
    }

    if (requireNumber) {
      rules.add(
        PasswordRule(
          label: context.translate(LanguageLabelKeys.passwordRuleNumber),
          satisfied: RegExp(r'[0-9]').hasMatch(value),
        ),
      );
    }

    if (requireSpecial) {
      rules.add(
        PasswordRule(
          label: context.translate(LanguageLabelKeys.passwordRuleSpecial),
          satisfied: RegExp(
            r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/;+=~`]',
          ).hasMatch(value),
        ),
      );
    }

    return rules;
  }

  bool isValid(BuildContext context, String value) =>
      evaluate(context, value).every((rule) => rule.satisfied);
}
