import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/password_policy.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class PasswordRequirementsChecklist extends StatelessWidget {
  final String password;
  final PasswordPolicy policy;

  const PasswordRequirementsChecklist({
    super.key,
    required this.password,
    required this.policy,
  });

  @override
  Widget build(BuildContext context) {
    final rules = policy.evaluate(context, password);
    final green = context.cs.onSecondaryContainer;

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: ThemeConstants.spaceXS,
      children: rules.map((rule) {
        return Row(
          mainAxisSize: .min,
          children: [
            AppSvgIcon(
              rule.satisfied
                  ? AssetsConstants.checkIcon
                  : AssetsConstants.closeIcon,
              size: ThemeConstants.iconXS,
              color: rule.satisfied ? green : context.cs.onSurfaceVariant,
            ),
            AppSpacing.w6,
            AppText(
              rule.label,
              style: context.tt.bodySmall?.copyWith(
                color: rule.satisfied ? green : context.cs.onSurfaceVariant,
                fontWeight: rule.satisfied ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
