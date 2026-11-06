import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_date_range_picker.dart';
import 'package:deliveryboy/commons/widgets/date_range_filter_field.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/settlement_history_cubit.dart';
import '../models/settlement_entry_type.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

void showSettlementHistoryFilterSheet(
  BuildContext context, {
  VoidCallback? onClearSearch,
}) {
  final fundTransferCubit = context.read<SettlementHistoryCubit>();
  var tempSelected = SettlementEntryType.fromValue(
    fundTransferCubit.entryType,
  );
  var tempStartDate = fundTransferCubit.startDate;
  var tempEndDate = fundTransferCubit.endDate;
  final filters = [
    (context.translate(LanguageLabelKeys.all), SettlementEntryType.all),
    (
      context.translate(LanguageLabelKeys.deliveryCommission),
      SettlementEntryType.deliveryCommission,
    ),
    (
      context.translate(LanguageLabelKeys.returnCommission),
      SettlementEntryType.returnCommission,
    ),
    (
      context.translate(LanguageLabelKeys.withdrawal),
      SettlementEntryType.withdrawal,
    ),
    (
      context.translate(LanguageLabelKeys.cashDepositCash),
      SettlementEntryType.cashDepositCash,
    ),
    (
      context.translate(LanguageLabelKeys.cashDepositWallet),
      SettlementEntryType.cashDepositWallet,
    ),
  ];

  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.filters),
    padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingXL, ThemeConstants.paddingM, ThemeConstants.paddingXL, ThemeConstants.paddingXXL),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        return SlideAnimationList(
          crossAxisAlignment: .start,
          children: [
            AppText(
              ctx.translate(LanguageLabelKeys.dateRange),
              style: ctx.tt.labelLarge,
            ),
            AppSpacing.h8,
            DateRangeFilterField(
              startDate: tempStartDate,
              endDate: tempEndDate,
              onTap: () async {
                final now = DateTime.now();
                final range = await showAppDateRangePicker(
                  context: ctx,
                  firstDate: DateTime(now.year - 2),
                  lastDate: now,
                  initialDateRange:
                      tempStartDate != null && tempEndDate != null
                      ? DateTimeRange(
                          start: DateTime.parse(tempStartDate!),
                          end: DateTime.parse(tempEndDate!),
                        )
                      : null,
                );
                if (range == null) return;
                setSheetState(() {
                  tempStartDate = range.start.toApiDateString();
                  tempEndDate = range.end.toApiDateString();
                });
              },
              onClear: () => setSheetState(() {
                tempStartDate = null;
                tempEndDate = null;
              }),
            ),
            AppSpacing.h20,
            AppText(
              ctx.translate(LanguageLabelKeys.filterByType),
              style: ctx.tt.labelLarge,
            ),
            RadioGroup<SettlementEntryType>(
              groupValue: tempSelected,
              onChanged: (val) {
                if (val != null) setSheetState(() => tempSelected = val);
              },
              child: SlideAnimationList(
                children: filters
                    .map(
                      (f) => RadioListTile<SettlementEntryType>(
                        title: AppText(f.$1),
                        value: f.$2,
                        activeColor: ctx.cs.primary,
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: EdgeInsetsDirectional.zero,
                        visualDensity: const VisualDensity(
                          horizontal: 0,
                          vertical: -4,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            AppSpacing.h28,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: ctx.translate(LanguageLabelKeys.clear),
                    variant: AppButtonVariant.outline,
                    height: ctx.heightFraction(0.05),
                    onPressed: () {
                      AppNavigator.pop(sheetCtx);
                      // Only re-fetch when a filter is actually applied —
                      // otherwise there's nothing to clear server-side, so
                      // just close the sheet.
                      if (fundTransferCubit.hasActiveFilters) {
                        onClearSearch?.call();
                        fundTransferCubit.clearFilters();
                      }
                    },
                  ),
                ),
                AppSpacing.w12,
                Expanded(
                  child: AppButton(
                    label: ctx.translate(LanguageLabelKeys.apply),
                    height: ctx.heightFraction(0.05),
                    onPressed: () {
                      AppNavigator.pop(sheetCtx);
                      fundTransferCubit.updateFilters(
                        entryType: tempSelected.value,
                        startDate: tempStartDate,
                        endDate: tempEndDate,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
