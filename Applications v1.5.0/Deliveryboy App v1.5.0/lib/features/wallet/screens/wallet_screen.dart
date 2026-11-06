import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/utils/debouncer.dart';
import 'package:deliveryboy/commons/utils/pagination_scroll_controller.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/commons/widgets/sticky_bar.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/list_skeleton_loader.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_filter_sheet.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_loaded_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/extensions/context_extensions.dart';
import '../../../utils/extensions/localization_extensions.dart';
import '../cubit/wallet_cubit.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import '../../../commons/widgets/app_text.dart';

/// Screen showing wallet balance, transaction history, search and status filters.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final PaginationScrollController _scrollController;
  final _debounceTimer = Debouncer();
  bool _isSearching = false;

  /// App bar shadow only while scrolled and the sticky balance bar isn't
  /// showing — once it's docked under the app bar it casts its own shadow,
  /// and the app bar's would just double up right above it.
  final ValueNotifier<bool> _appBarShadowVisible = ValueNotifier(false);

  void _updateAppBarShadow() {
    final c = _scrollController.controller;
    final offset = c.hasClients ? c.offset : 0.0;
    _appBarShadowVisible.value =
        offset > 0 && !StickyBar.isVisibleAt(offset);
  }

  @override
  void initState() {
    super.initState();
    context.read<WalletCubit>().loadWallet();
    _scrollController = PaginationScrollController(
      onLoadMore: () => context.read<WalletCubit>().loadMore(),
    );
    _scrollController.controller.addListener(_updateAppBarShadow);
  }

  @override
  void dispose() {
    _scrollController.controller.removeListener(_updateAppBarShadow);
    _appBarShadowVisible.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer(() {
      context.read<WalletCubit>().search(query);
    });
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _cancelSearch() {
    setState(() => _isSearching = false);
    final hadText = _searchController.text.trim().isNotEmpty;
    _searchController.clear();
    if (hadText) _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          context.read<WalletCubit>().loadWallet();
        }
      },
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityDisconnected;
        return AppScaffold(
          applyBottomInset: false,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.wallet),
            showBackButton: true,
            shadowListenable: _appBarShadowVisible,
            isSearching: _isSearching,
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onSearchStart: _startSearch,
            onSearchCancel: _cancelSearch,
            searchHint: context.translate(LanguageLabelKeys.searchTransactions),
            actions: [
              if (!_isSearching)
                Builder(
                  builder: (ctx) => IconButton(
                    icon: AppSvgIcon(
                      AssetsConstants.filterIcon,
                      size: ThemeConstants.iconM,
                      color: context.cs.onSurfaceVariant,
                    ),
                    onPressed: () => showWalletFilterSheet(context),
                  ),
                ),
              AppSpacing.w4,
            ],
          ),
          // Offline state lives in the body so the app bar — and its back
          // button — stays available on this pushed route.
          body: isOffline
              ? AppNoInternetFullScreen(
                  embedded: true,
                  onRetry: () => context.read<WalletCubit>().loadWallet(),
                )
              : BlocBuilder<WalletCubit, WalletState>(
                  builder: (context, state) {
                    if (state is WalletLoading) {
                      return const ListSkeletonLoader(showHeroCard: true);
                    }
                    if (state is WalletError) {
                      return EmptyStateWidget(
                        imagePath: AssetsConstants.noWalletFound,
                        title: state.message,
                        subtitle: context.translate(
                          LanguageLabelKeys.pullDownToRefresh,
                        ),
                        onRetry: () => context.read<WalletCubit>().loadWallet(),
                      );
                    }
                    if (state is WalletLoaded) {
                      return WalletLoadedBody(
                        state: state,
                        scrollController: _scrollController.controller,
                      );
                    }
                    return Center(
                      child: AppText(
                        context.translate(LanguageLabelKeys.somethingWentWrong),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
