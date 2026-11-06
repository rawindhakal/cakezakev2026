import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class ChatDateDivider extends StatelessWidget {
  final DateTime date;
  const ChatDateDivider({super.key, required this.date});

  String _label(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    if (msgDay == today) return context.translate(LanguageLabelKeys.today);
    if (msgDay == today.subtract(const Duration(days: 1))) {
      return context.translate(LanguageLabelKeys.yesterday);
    }
    return AppDateFormatter.formatDateTime(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: ThemeConstants.paddingM),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.cs.outlineVariant, height: 1)),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: ThemeConstants.paddingM),
            child: AppText(
              _label(context),
              style: context.tt.labelSmall?.copyWith(
                color: context.cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.cs.outlineVariant, height: 1)),
        ],
      ),
    );
  }
}
