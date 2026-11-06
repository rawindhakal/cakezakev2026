import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/wallet/cubit/wallet_cubit.dart';
import 'package:deliveryboy/features/wallet/cubit/withdrawal_cubit.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';

void showWithdrawalSheet(BuildContext context) {
  final walletCubit = context.read<WalletCubit>();
  final currencySymbol = context
      .read<CountrySettingsCubit>()
      .getCurrencySymbol();

  showAppBottomSheet(
    context,
    isScrollControlled: true,
    title: context.translate(LanguageLabelKeys.withdrawalRequest),
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingXL,
      ThemeConstants.paddingM,
      ThemeConstants.paddingXL,
      ThemeConstants.paddingXXL,
    ),
    builder: (sheetContext) => BlocProvider(
      create: (_) => WithdrawalCubit(),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _WithdrawalSheet(
          currencySymbol: currencySymbol,
          onSuccess: () => walletCubit.loadWallet(),
        ),
      ),
    ),
  );
}

class _WithdrawalSheet extends StatefulWidget {
  final String currencySymbol;
  final VoidCallback onSuccess;

  const _WithdrawalSheet({
    required this.currencySymbol,
    required this.onSuccess,
  });

  @override
  State<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends State<_WithdrawalSheet> {
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WithdrawalCubit, WithdrawalState>(
      listener: (ctx, state) {
        if (state is WithdrawalLoaded) {
          AppNavigator.pop(context);
          widget.onSuccess();
          AppSnackBar.show(
            context: context,
            message: context.translate(LanguageLabelKeys.withdrawalSuccess),
            type: SnackBarType.success,
          );
        } else if (state is WithdrawalError) {
          AppSnackBar.show(
            context: context,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      builder: (ctx, state) {
        final isLoading = state is WithdrawalLoading;
        return SingleChildScrollView(
          child: SlideAnimationList(
            crossAxisAlignment: .start,
            children: [
              AppTextField(
                controller: _amountController,
                hintText: context.translate(LanguageLabelKeys.enterAmount),
                labelText: context.translate(LanguageLabelKeys.amount),
                keyboardType: TextInputType.number,
              ),
              AppSpacing.h16,
              AppTextField(
                controller: _messageController,
                hintText: context.translate(LanguageLabelKeys.enterMessage),
                labelText: context.translate(LanguageLabelKeys.messageOptional),
                maxLines: 3,
              ),
              AppSpacing.h24,
              Row(
                spacing: ThemeConstants.spaceM,
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.translate(LanguageLabelKeys.cancel),
                      variant: AppButtonVariant.outline,
                      color: context.cs.onSurfaceVariant,
                      onPressed: isLoading
                          ? null
                          : () => AppNavigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: context.translate(LanguageLabelKeys.submit),
                      isLoading: isLoading,
                      onPressed: () {
                        final amount = _amountController.text.trim();
                        if (amount.isEmpty) return;
                        ctx.read<WithdrawalCubit>().submit(
                          amount: amount,
                          message: _messageController.text.trim(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
