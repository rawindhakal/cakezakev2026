import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

class AuthScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceS,
      children: [
        AppText(
          title,
          style: context.tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        AppText(
          subtitle,
          style: context.tt.bodyMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
