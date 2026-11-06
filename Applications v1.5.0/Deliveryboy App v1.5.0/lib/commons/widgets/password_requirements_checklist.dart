import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/password_policy.dart';
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
    final green = Colors.green.shade600;

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
              size: ThemeConstants.iconM,
              color: rule.satisfied ? green : context.cs.onSurfaceVariant,
            ),
            SizedBox(width: context.screenWidth * 0.016),
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
