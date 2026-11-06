import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/sticky_bar.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_footer.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/wallet/widgets/withdrawal_sheet.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/wallet_cubit.dart';
import 'wallet_balance_card.dart';
import 'wallet_transaction_item.dart';

/// Renders the wallet balance card and paginated transaction list once wallet data is loaded.
class WalletLoadedBody extends StatelessWidget {
  final WalletLoaded state;
  final ScrollController scrollController;

  const WalletLoadedBody({
    super.key,
    required this.state,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final transactions = state.data;
    final balance = context.read<WalletCubit>().balance;
    final balanceCard = WalletBalanceCard(
      balance: balance,
      onWithdraw: () => showWithdrawalSheet(context),
    );

    if (transactions.isEmpty) {
      return Column(
        children: [
          balanceCard,
          Expanded(
            child: EmptyStateWidget(
              imagePath: AssetsConstants.noWalletFound,
              title: context.translate(LanguageLabelKeys.noTransactionsYet),
              subtitle: context.translate(LanguageLabelKeys.noTransactionsDesc),
            ),
          ),
        ],
      );
    }

    final list = RefreshIndicator(
      color: context.cs.primary,
      onRefresh: () async => context.read<WalletCubit>().loadWallet(),
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(
          0,
          0,
          0,
          context.bottomSafePadding,
        ),
        // +1 for the balance card at index 0.
        itemCount: transactions.length + 1 + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) return balanceCard;
          final itemIndex = index - 1;
          if (itemIndex >= transactions.length) {
            return const PaginatedListFooter(
              isLoadingMore: true,
              hasMore: true,
            );
          }
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingL,
            ),
            child: WalletTransactionItem(transaction: transactions[itemIndex]),
          );
        },
      ),
    );

    return Stack(
      children: [
        list,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: StickyBar(
            controller: scrollController,
            label: context.translate(LanguageLabelKeys.availableBalance),
            amountText:
                '${context.read<CountrySettingsCubit>().getCurrencySymbol()}${balance.toStringAsFixed(0)}',
          ),
        ),
      ],
    );
  }
}
