import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/wallet_cubit.dart';
import '../models/withdrawal_status.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

void showWalletFilterSheet(BuildContext context) {
  final walletCubit = context.read<WalletCubit>();
  final filters = [
    (context.translate(LanguageLabelKeys.all), WithdrawalStatus.all),
    (context.translate(LanguageLabelKeys.pending), WithdrawalStatus.pending),
    (context.translate(LanguageLabelKeys.approved), WithdrawalStatus.approved),
    (context.translate(LanguageLabelKeys.rejected), WithdrawalStatus.rejected),
  ];

  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.filterByStatus),
    padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingXL, ThemeConstants.paddingM, ThemeConstants.paddingXL, ThemeConstants.paddingXXL),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        WithdrawalStatus selected = WithdrawalStatus.fromValue(
          walletCubit.selectedStatus,
        );
        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            RadioGroup<WithdrawalStatus>(
              groupValue: selected,
              onChanged: (val) {
                if (val != null) {
                  setSheetState(() => selected = val);
                  walletCubit.filterByStatus(val.value);
                  AppNavigator.pop(context);
                }
              },
              child: SlideAnimationList(
                children: filters
                    .map(
                      (f) => RadioListTile<WithdrawalStatus>(
                        title: AppText(f.$1),
                        value: f.$2,
                        activeColor: context.cs.primary,
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
          ],
        );
      },
    ),
  );
}
