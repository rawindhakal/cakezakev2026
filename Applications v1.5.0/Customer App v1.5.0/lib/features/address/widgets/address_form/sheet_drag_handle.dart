import 'package:flutter/material.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Small pill drag indicator shown at the top of the sheet.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsetsDirectional.only(
          top: ThemeConstants.paddingM,
          bottom: ThemeConstants.paddingXS,
        ),
        decoration: AppDecorations.dragHandle(color: context.cs.outlineVariant),
      ),
    );
  }
}
