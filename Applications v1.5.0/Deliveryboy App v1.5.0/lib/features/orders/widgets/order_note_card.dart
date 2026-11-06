import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/section_icon_header.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Note card for the customer's delivery instruction — same
/// icon+title/divider/body layout as the return-order info card, so both
/// read as one consistent "note" pattern across order-detail screens.
class OrderNoteCard extends StatelessWidget {
  final String note;
  const OrderNoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingL),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          SectionIconHeader(
            icon: AssetsConstants.noteIcon,
            title: context.translate(LanguageLabelKeys.orderNote),
          ),
          AppSpacing.h10,
          AppText(
            note,
            style: context.tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w400,
              color: context.cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
