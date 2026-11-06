import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

class AuthResendSection extends StatelessWidget {
  final Duration resendTimer;
  final VoidCallback onResend;

  const AuthResendSection({
    super.key,
    required this.resendTimer,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final canResend = resendTimer.inSeconds == 0;
    return Center(
      child: Column(
        spacing: ThemeConstants.spaceS,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.didNotReceiveCode),
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurfaceVariant,
            ),
          ),
          if (canResend)
            GestureDetector(
              onTap: onResend,
              child: AppText(
                context.translate(LanguageLabelKeys.resendOtp),
                style: context.tt.labelMedium?.copyWith(
                  color: context.cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            AppText(
              '${context.translate(LanguageLabelKeys.resendIn)} ${resendTimer.inSeconds}s',
              style: context.tt.bodySmall?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
