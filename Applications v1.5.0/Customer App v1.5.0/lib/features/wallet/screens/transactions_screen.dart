import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/features/wallet/cubit/transaction_cubit.dart';
import 'package:customer/features/wallet/models/transaction_model.dart';
import 'package:customer/features/wallet/widgets/transaction_item.dart';
import 'package:customer/features/wallet/widgets/transaction_list_skeleton_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => context.read<TransactionCubit>().fetchMore(),
  );

  final _scrolled = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    context.read<TransactionCubit>().fetchInitial();
  }

  @override
  void dispose() {
    _pager.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          context.read<TransactionCubit>().fetchInitial();
        }
      },
      builder: (context, connectivityState) {
        return AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.transactionHistory),
            shadowListenable: _scrolled,
          ),
          // Offline replaces the body only, so the app bar's back button
          // keeps working.
          body: connectivityState is ConnectivityDisconnected
              ? const AppNoInternetView()
              : BlocBuilder<TransactionCubit, PaginationState<TransactionData>>(
                  builder: (context, state) {
                    if (state is PaginationInitial<TransactionData>) {
                      context.read<TransactionCubit>().fetchInitial();
                      return const TransactionListSkeletonLoader();
                    }
                    if (state is PaginationLoading<TransactionData>) {
                      return const TransactionListSkeletonLoader();
                    }
                    if (state is PaginationError<TransactionData>) {
                      return EmptyStateWidget(
                        imagePath: AssetsConstants.noTransactionFound,
                        title: state.message,
                        subtitle: context.translate(
                          LanguageLabelKeys.pullToRefresh,
                        ),
                        onRetry: () =>
                            context.read<TransactionCubit>().fetchInitial(),
                      );
                    }
                    if (state is PaginationLoaded<TransactionData>) {
                      return _buildList(context, state);
                    }
                    return AppSpacing.shrink;
                  },
                ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    PaginationLoaded<TransactionData> state,
  ) {
    if (state.data.isEmpty) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noTransactionFound,
        title: context.translate(LanguageLabelKeys.noTransactions),
        subtitle: context.translate(LanguageLabelKeys.transactionHistoryEmpty),
      );
    }

    return RefreshIndicator(
      color: context.cs.primary,
      onRefresh: () async => context.read<TransactionCubit>().refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
            _scrolled.value = n.metrics.pixels > 0;
          }
          return false;
        },
        child: _pager.attach(
          ListView.builder(
            controller: _pager.controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingL,
              ThemeConstants.paddingM,
              ThemeConstants.paddingL,
              ThemeConstants.paddingL + context.bottomSafePadding,
            ),
            itemCount: state.data.length + (state.isFetchingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.data.length) {
                return PaginatedListFooter(
                  isLoadingMore: state.isFetchingMore,
                  hasMore: state.hasMore,
                  skeletonBuilder: (_) => const TransactionListSkeletonLoader(
                    itemCount: 1,
                    shrinkWrap: true,
                  ),
                );
              }
              return TransactionItem(txn: state.data[index]);
            },
          ),
        ),
      ),
    );
  }
}
