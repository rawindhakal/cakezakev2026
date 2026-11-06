import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Small label used above each flat form section.
class FlatSectionLabel extends StatelessWidget {
  final String title;

  const FlatSectionLabel(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: ThemeConstants.paddingM,
      ),
      child: AppText(
        title,
        style: context.tt.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: context.cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
