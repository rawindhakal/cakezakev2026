import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'dart:async';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/features/wallet/cubit/wallet_transaction_cubit.dart';
import 'package:customer/features/wallet/models/wallet_history_model.dart';
import 'package:customer/features/wallet/models/wallet_txn_type.dart';
import 'package:customer/features/wallet/widgets/wallet_add_money_sheet.dart';
import 'package:customer/features/wallet/widgets/wallet_balance_card.dart';
import 'package:customer/features/wallet/widgets/wallet_transaction_item.dart';
import 'package:customer/features/wallet/widgets/transaction_list_skeleton_loader.dart';
import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/commons/widgets/sticky_bar.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';

class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  State<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => context.read<WalletTransactionCubit>().fetchMore(),
  );
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isSearching = false;
  WalletTxnType? _selectedType;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<WalletTransactionCubit>().fetchInitial();
  }

  @override
  void dispose() {
    _pager.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = query.trim().toLowerCase());
    });
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _searchController.clear();
  }

  List<WalletHistoryData> _applyFilters(List<WalletHistoryData> all) {
    return all.where((t) {
      final matchType =
          _selectedType == null ||
          WalletTxnType.fromApiValue(t.type) == _selectedType;
      final q = _searchQuery;
      final matchSearch =
          q.isEmpty ||
          (t.paymentType ?? '').toLowerCase().contains(q) ||
          (t.txnId ?? '').toLowerCase().contains(q) ||
          (t.message ?? '').toLowerCase().contains(q);
      return matchType && matchSearch;
    }).toList();
  }

  void _showFilterSheet() {
    final filters = <(String, WalletTxnType?)>[
      (context.translate(LanguageLabelKeys.filterAll), null),
      (context.translate(LanguageLabelKeys.credit), WalletTxnType.credit),
      (context.translate(LanguageLabelKeys.debit), WalletTxnType.debit),
    ];
    showAppBottomSheet(
      context,
      isScrollControlled: false,
      title: context.translate(LanguageLabelKeys.filterByType),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingXXL,
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          WalletTxnType? sel = _selectedType;
          return RadioGroup<WalletTxnType?>(
            groupValue: sel,
            onChanged: (val) {
              setSheet(() => sel = val);
              setState(() => _selectedType = val);
              AppNavigator.pop(context);
            },
            child: SlideAnimationList(
              children: filters
                  .map(
                    (f) => RadioListTile<WalletTxnType?>(
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          context.read<WalletTransactionCubit>().fetchInitial();
        }
      },
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityDisconnected;
        return AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.walletHistory),
            scrollController: _pager.controller,
            hideShadowAfter: StickyBar.showAfter,
            isSearching: _isSearching,
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onSearchStart: _startSearch,
            onSearchCancel: _cancelSearch,
            inlineSearchCancel: true,
            searchHint: context.translate(LanguageLabelKeys.searchTransactions),
            actions: [
              if (!_isSearching)
                IconButton(
                  icon: Badge(
                    isLabelVisible: _selectedType != null,
                    child: AppSvgIcon(
                      AssetsConstants.filterIcon,
                      size: ThemeConstants.iconL,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  onPressed: _showFilterSheet,
                ),
              AppSpacing.w4,
            ],
          ),
          // Offline replaces the body only, so the app bar's back button
          // keeps working.
          body: isOffline
              ? const AppNoInternetView()
              : BlocBuilder<
                  WalletTransactionCubit,
                  PaginationState<WalletHistoryData>
                >(
                  builder: (context, state) {
                    if (state is PaginationInitial<WalletHistoryData>) {
                      context.read<WalletTransactionCubit>().fetchInitial();
                    }
                    if (state is PaginationLoaded<WalletHistoryData>) {
                      return _buildList(context, state);
                    }
                    // Non-list states keep the balance card fixed on top.
                    return Column(
                      children: [
                        _buildBalanceCard(),
                        Expanded(child: _buildStateBody(context, state)),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildBalanceCard() => WalletBalanceCard(
    onAddMoney: () => showAddMoneySheet(
      context,
      onSuccess: () => context.read<WalletTransactionCubit>().fetchInitial(),
    ),
  );

  Widget _buildStateBody(
    BuildContext context,
    PaginationState<WalletHistoryData> state,
  ) {
    if (state is PaginationError<WalletHistoryData>) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noTransactionFound,
        title: state.message,
        subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
        onRetry: () => context.read<WalletTransactionCubit>().fetchInitial(),
      );
    }
    if (state is PaginationInitial<WalletHistoryData> ||
        state is PaginationLoading<WalletHistoryData>) {
      return const TransactionListSkeletonLoader(outlined: true);
    }
    return AppSpacing.shrink;
  }

  // Filter/search narrows only the already-fetched page. If matches are too
  // few to fill (and scroll) the list, `_onScroll` never fires, so
  // fetchMore would never run and later matching pages would be missed.
  // Keep pulling more pages until either enough matches show up or the
  // server runs out.
  static const int _minFilterResults = 8;

  Widget _buildList(
    BuildContext context,
    PaginationLoaded<WalletHistoryData> state,
  ) {
    final filtered = _applyFilters(state.data);
    final hasActiveFilter = _searchQuery.isNotEmpty || _selectedType != null;

    if (hasActiveFilter &&
        filtered.length < _minFilterResults &&
        state.hasMore &&
        !state.isFetchingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<WalletTransactionCubit>().fetchMore();
      });
    }

    if (filtered.isEmpty) {
      final Widget empty = hasActiveFilter && state.hasMore
          ? const TransactionListSkeletonLoader(outlined: true)
          : _buildEmpty(context, hasActiveFilter);
      return Column(
        children: [
          _buildBalanceCard(),
          Expanded(child: empty),
        ],
      );
    }

    return _buildTransactionList(context, state, filtered);
  }

  Widget _buildEmpty(BuildContext context, bool hasActiveFilter) {
    return EmptyStateWidget(
      imagePath: AssetsConstants.noTransactionFound,
      title: hasActiveFilter
          ? context.translate(LanguageLabelKeys.noMatchingTransactions)
          : context.translate(LanguageLabelKeys.noWalletHistory),
      subtitle: hasActiveFilter
          ? context.translate(LanguageLabelKeys.tryAgainClearFilters)
          : context.translate(LanguageLabelKeys.walletTransactionHistoryEmpty),
    );
  }

  Widget _buildTransactionList(
    BuildContext context,
    PaginationLoaded<WalletHistoryData> state,
    List<WalletHistoryData> filtered,
  ) {
    final currencySymbol = context
        .read<CountrySettingsCubit>()
        .getCurrencySymbol();

    final list = RefreshIndicator(
      color: context.cs.primary,
      onRefresh: () async {
        context.read<WalletTransactionCubit>().fetchInitial();
      },
      child: _pager.attach(
        ListView.builder(
          controller: _pager.controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.fromSTEB(
            0,
            0,
            0,
            ThemeConstants.paddingL + context.bottomSafePadding,
          ),
          // +1 for the balance card at index 0.
          itemCount: filtered.length + 1 + (state.isFetchingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) return _buildBalanceCard();
            final itemIndex = index - 1;
            if (itemIndex == filtered.length) {
              return PaginatedListFooter(
                isLoadingMore: state.isFetchingMore,
                hasMore: state.hasMore,
                skeletonBuilder: (_) => const TransactionListSkeletonLoader(
                  itemCount: 1,
                  outlined: true,
                  shrinkWrap: true,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingL,
              ),
              child: WalletTransactionItem(txn: filtered[itemIndex]),
            );
          },
        ),
      ),
    );

    return Stack(
      children: [
        list,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: ValueListenableBuilder<Box>(
            valueListenable: AuthHiveBox.instance.listenable,
            builder: (context, box, _) {
              final balance =
                  double.tryParse(AuthHiveBox.instance.userBalance) ?? 0.0;
              return StickyBar(
                controller: _pager.controller,
                label: context.translate(LanguageLabelKeys.availableBalance),
                amountText: '$currencySymbol${balance.formatPrice(2)}',
              );
            },
          ),
        ),
      ],
    );
  }
}
