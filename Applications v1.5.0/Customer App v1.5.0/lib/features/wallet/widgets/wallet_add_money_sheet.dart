import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/services/analytics_service.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/features/payment_method/models/enums/transaction_type.dart';
import 'package:customer/features/payment_method/screens/payment_methods_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';

void showAddMoneySheet(BuildContext context, {VoidCallback? onSuccess}) {
  final countrySettingsCubit = context.read<CountrySettingsCubit>();

  showAppBottomSheet(
    context,
    showDragHandle: false,
    padding: null,
    builder: (sheetContext) => Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _AddMoneySheet(
        currencySymbol: countrySettingsCubit.getCurrencySymbol(),
        decimalPoint: countrySettingsCubit.getDecimalPoint(),
        onSuccess: onSuccess ?? () {},
      ),
    ),
  );
}

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet({
    required this.currencySymbol,
    required this.decimalPoint,
    required this.onSuccess,
  });

  final String currencySymbol;
  final int decimalPoint;
  final VoidCallback onSuccess;

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.enterValidAmount),
        type: SnackBarType.error,
      );
      return;
    }

    // Capture before pop — context is invalid after sheet unmounts.
    final navigator = AppNavigator.of(context);
    final onSuccess = widget.onSuccess;
    final currency = widget.currencySymbol;

    navigator.pop();

    final result = await navigator.pushNamed(
      RouteNames.paymentMethods,
      arguments: PaymentArgs(
        orderId: '',
        amount: amount,
        currency: currency,
        userEmail: AuthHiveBox.instance.userEmail,
        isWalletTopUp: true,
        extra: {
          ApiParameters.amount: amountText,
          ApiParameters.type: TransactionType.wallet.apiValue,
        },
      ),
    );

    if (result == true) {
      AnalyticsService.instance.logEvent(
        AppConstants.eventWalletTopup,
        parameters: {
          AppConstants.paramAmount: amount,
          AppConstants.paramCurrency: currency,
        },
      );
      onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingXXL + context.bottomSafePadding,
      ),
      child: SlideAnimationList(
        crossAxisAlignment: .start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: AppDecorations.dragHandle(color: context.cs.outline),
            ),
          ),
          AppSpacing.h16,
          AppText(
            context.translate(LanguageLabelKeys.addMoneyToWallet),
            style: context.tt.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          AppSpacing.h20,
          AppTextField(
            controller: _amountController,
            hintText: context.translate(LanguageLabelKeys.enterAmount),
            labelText: context.translate(LanguageLabelKeys.amount),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                final text = newValue.text;
                if (text.isEmpty) return newValue;
                final dp = widget.decimalPoint;
                final reg = RegExp('^\\d*\\.?\\d{0,$dp}\$');
                return reg.hasMatch(text) ? newValue : oldValue;
              }),
            ],
          ),
          AppSpacing.h24,
          Row(
            spacing: ThemeConstants.spaceM,
            children: [
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.cancel),
                  onPressed: () => AppNavigator.pop(context),
                  variant: AppButtonVariant.outline,
                  color: context.cs.onSurfaceVariant,
                  height: 48,
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    vertical: ThemeConstants.paddingM,
                  ),
                ),
              ),
              Expanded(
                child: AppButton(
                  label: context.translate(LanguageLabelKeys.proceedToPay),
                  onPressed: _proceed,
                  height: 48,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
