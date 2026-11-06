import 'package:flutter/material.dart';
import '../../commons/widgets/app_text.dart';
import '../../utils/extensions/context_extensions.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        AppText(
          title,
          style: context.tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.onSurface,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: AppText(
              actionLabel!,
              style: context.tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.cs.primary,
              ),
            ),
          ),
      ],
    );
  }
}
