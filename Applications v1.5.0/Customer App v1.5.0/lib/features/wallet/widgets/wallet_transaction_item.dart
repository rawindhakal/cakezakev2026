import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/payment_method/models/enums/order_payment_method.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/wallet/models/wallet_history_model.dart';
import 'package:customer/features/wallet/models/wallet_txn_type.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';

class WalletTransactionItem extends StatelessWidget {
  final WalletHistoryData txn;
  const WalletTransactionItem({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<CountrySettingsCubit>();
    final currencySymbol = txn.currency;
    final decimalPoint = settings.getDecimalPoint();
    final formattedAmount = (double.tryParse(txn.amount ?? '0') ?? 0.0)
        .formatPrice(decimalPoint);
    final txnType = WalletTxnType.fromApiValue(txn.type);
    final (amountColor, typeLabel) = _typeMeta(
      context,
      txnType,
      txn.type ?? '',
    );
    final isCredit = txnType == WalletTxnType.credit;
    final paymentIcon = _paymentIcon(txn.paymentType);
    final isTintableIcon =
        paymentIcon == AssetsConstants.orderIcon ||
        paymentIcon == AssetsConstants.walletIcon;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingS),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              crossAxisAlignment: .center,
              spacing: ThemeConstants.spaceM,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: AppDecorations.box(
                    color: context.cs.onSurfaceVariant.withValues(alpha: 0.15),
                    borderRadius: AppRadius.r8,
                  ),
                  alignment: Alignment.center,
                  child: AppSvgIcon(
                    paymentIcon,
                    size: ThemeConstants.iconM,
                    color: isTintableIcon ? context.cs.onSurfaceVariant : null,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceXXS,
                    children: [
                      AppText(
                        (txn.paymentType?.isNotEmpty == true)
                            ? txn.paymentType!
                            : '${context.translate(LanguageLabelKeys.orderId)} ${AppConstants.hashSymbol}${txn.orderId ?? '-'}',
                        style: context.tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                      if (txn.txnId?.isNotEmpty == true) ...[
                        AppText(
                          '${context.translate(LanguageLabelKeys.txnId)}: ${txn.txnId}',
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      ] else if (txn.paymentType?.isNotEmpty == true) ...[
                        AppText(
                          '${context.translate(LanguageLabelKeys.orderId)} ${AppConstants.hashSymbol}${txn.orderId ?? '-'}',
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AppText(
                  typeLabel,
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
            if ((txn.message ?? '').isNotEmpty) ...[
              AppSpacing.h10,
              Divider(
                height: 1,
                color: context.cs.outlineVariant.withValues(
                  alpha: context.isDark ? 0.25 : 0.5,
                ),
              ),
              AppSpacing.h8,
              AppText(
                txn.message ?? '',
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
            AppSpacing.h8,
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Expanded(
                  child: AppText(
                    AppDateFormatter.formatDateTime(txn.createdAt),
                    style: context.tt.labelSmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                ),
                AppText(
                  '${isCredit ? '+' : '-'}$currencySymbol$formattedAmount',
                  style: context.tt.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, String) _typeMeta(
    BuildContext context,
    WalletTxnType? type,
    String rawType,
  ) => switch (type) {
    WalletTxnType.credit => (
      context.cs.onSecondaryContainer,
      context.translate(LanguageLabelKeys.credit),
    ),
    WalletTxnType.debit => (
      context.cs.error,
      context.translate(LanguageLabelKeys.debit),
    ),
    null => (context.cs.onSurfaceVariant, rawType),
  };

  String _paymentIcon(String? paymentType) {
    if (paymentType == null || paymentType.isEmpty) {
      return AssetsConstants.orderIcon;
    }
    if (OrderPaymentMethod.fromRaw(paymentType) == OrderPaymentMethod.wallet) {
      return AssetsConstants.walletIcon;
    }
    // Backend sends display casing (e.g. "PayU"), so match case-insensitively.
    final normalized = paymentType.trim().toLowerCase();
    for (final gateway in PaymentGatewayType.values) {
      if (normalized == gateway.apiValue.toLowerCase()) {
        return gateway.iconPath;
      }
    }
    return AssetsConstants.walletIcon;
  }
}
