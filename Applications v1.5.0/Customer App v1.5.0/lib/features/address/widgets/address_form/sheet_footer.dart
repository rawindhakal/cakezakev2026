import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Sticky footer bar that hosts the primary save/update action.
class SheetFooter extends StatelessWidget {
  final Widget child;

  const SheetFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingXL,
      ),
      decoration: AppDecorations.bottomSheetFooter(
        color: context.cs.surface,
        borderColor: context.cs.outlineVariant.withValues(alpha: 0.3),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
