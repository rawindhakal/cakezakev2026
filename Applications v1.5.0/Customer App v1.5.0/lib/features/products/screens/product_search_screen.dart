import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'dart:async';

import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/commons/widgets/app_search_filter_bar.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/product_listing_view.dart';
import 'package:customer/commons/widgets/wave_text.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:customer/features/products/cubit/search_product_cubit.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_card_skeleton.dart';
import 'package:customer/features/products/widgets/recent_searches_view.dart';
import 'package:customer/features/products/widgets/search_wishlist_section.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/favourite/cubit/favorite_cubit.dart';
import 'package:customer/features/products/widgets/voice_search_sheet.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';

typedef _SearchState = PaginationState<ProductDataModel>;
typedef _SearchLoaded = PaginationLoaded<ProductDataModel>;
typedef _SearchError = PaginationError<ProductDataModel>;
typedef _SearchLoading = PaginationLoading<ProductDataModel>;
typedef _SearchInitial = PaginationInitial<ProductDataModel>;

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key, this.searchSuggestions});

  // Rotating placeholder words, same ones the home search bar shows.
  // Null/empty (no API data) falls back to the static hint — no hardcoding.
  final List<String>? searchSuggestions;

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final bool _isGrid = true;

  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  int _crossAxisCount(BuildContext context) => _isTablet(context) ? 5 : 3;

  final TextEditingController _searchController = TextEditingController();
  late final _pager = PaginationScrollController(
    onLoadMore: () => context.read<SearchProductCubit>().fetchMore(),
  );
  Timer? _debounce;
  // context is unsafe to read() from inside dispose() (widget may already be
  // deactivated) — grab the cubit while the tree is still stable instead.
  late final SearchProductCubit _searchCubit = context
      .read<SearchProductCubit>();

  // Bumped to remount (and thus replay) the title's WaveText — once on
  // first open, then again whenever the list is scrolled down and back up.
  int _titleWaveTrigger = 0;
  bool _scrolledAwayFromTop = false;

  @override
  void initState() {
    super.initState();
    // Force the late field to evaluate now, while context is safe to read.
    _searchCubit;
    // Load the unfiltered product list on open (no search param) — recent
    // searches render alongside it rather than replacing it.
    _searchCubit.fetchInitial();
    // Wishlist row is logged-in only — guests never hit the favourites API.
    if (AuthHiveBox.instance.isLoggedIn) {
      context.read<FavoriteCubit>().loadFavorites();
    }
    _pager.controller.addListener(_onTitleWaveScroll);
  }

  void _onTitleWaveScroll() {
    if (!_pager.controller.hasClients) return;
    final offset = _pager.controller.offset;
    if (offset > 80) {
      _scrolledAwayFromTop = true;
    } else if (offset <= 4 && _scrolledAwayFromTop) {
      _scrolledAwayFromTop = false;
      setState(() => _titleWaveTrigger++);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Leaving with a typed-but-never-submitted query still counts as intent
    // — save it, mirroring Blinkit/Zomato-style implicit history capture.
    _searchCubit.saveImplicitSearch(_searchController.text);
    _searchController.dispose();
    _pager.controller.removeListener(_onTitleWaveScroll);
    _pager.dispose();
    super.dispose();
  }

  void _openVoiceSearch() {
    showVoiceSearchSheet(
      context,
      onResult: (query) {
        _searchController.text = query;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: query.length),
        );
        _onQuerySubmitted(query);
      },
    );
  }

  static const int _minSearchLength = 3;

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    // Below 3 chars: don't hit the API or save history, just wait for more
    // input (empty query is the exception — it resets to the recent list).
    if (trimmed.isNotEmpty && trimmed.length < _minSearchLength) {
      setState(() {});
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final cubit = context.read<SearchProductCubit>();
      cubit.search(query);
      // Save as soon as the debounce settles on this query, not deferred to
      // dispose() — otherwise clearing the box (e.g. after a no-results
      // search) before leaving wipes the text and the term never gets saved.
      cubit.saveImplicitSearch(query);
    });
    setState(() {});
  }

  void _onQuerySubmitted(String query) {
    _debounce?.cancel();
    context.read<SearchProductCubit>().submitSearch(query);
  }

  void _onRecentSearchTap(String query) {
    _debounce?.cancel();
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    context.read<SearchProductCubit>().submitSearch(query);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      appBar: CustomAppBar(
        showBackButton: false,
        scrollController: _pager.controller,
        titleWidget: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: ThemeConstants.paddingS,
            end: ThemeConstants.paddingS,
            top: ThemeConstants.paddingXS,
            bottom: ThemeConstants.paddingXS,
          ),
          child: AppSearchFilterBar(
            searchController: _searchController,
            onSearchChanged: _onQueryChanged,
            onSubmitted: _onQuerySubmitted,
            hintText: context.translate(LanguageLabelKeys.searchProductsHint),
            hintSuggestions: widget.searchSuggestions,
            onMicTap: _openVoiceSearch,
            prefixIconAsset: AssetsConstants.arrowLeftIcon,
            onPrefixTap: () => AppNavigator.pop(context),
            autofocus: true,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    final cubit = context.read<SearchProductCubit>();
                    if (cubit.state is! _SearchLoaded) return;
                    cubit.refresh();
                    await cubit.stream.firstWhere((s) => s is! _SearchLoading);
                  },
                  child: _buildBody(),
                ),
                Positioned(
                  bottom: context.bottomSafePadding,
                  left: 0,
                  right: 0,
                  child: FloatingCartBar(
                    onViewCart: () =>
                        AppNavigator.pushNamed(context, RouteNames.checkout),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<SearchProductCubit, _SearchState>(
      builder: (context, state) {
        if (state is _SearchInitial) {
          return const SizedBox.shrink();
        }
        if (state is _SearchLoading) {
          return _isGrid
              ? ProductGridSkeleton(
                  crossAxisCount: _crossAxisCount(context),
                  edgePad: 32,
                  spacing:
                      ThemeConstants.spaceM * (_isTablet(context) ? 1.75 : 1.0),
                  mainAxisSpacing: 16 * (_isTablet(context) ? 1.75 : 1.0),
                )
              : const ProductListSkeleton();
        }
        if (state is _SearchError) {
          return EmptyStateWidget(
            imagePath: AssetsConstants.noSearchFound,
            title: state.message,
            subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
            onRetry: () => context.read<SearchProductCubit>().search(
              _searchController.text,
            ),
          );
        }
        if (state is _SearchLoaded) {
          if (state.data.isEmpty) {
            return EmptyStateWidget(
              imagePath: AssetsConstants.noSearchFound,
              title: context.translate(LanguageLabelKeys.noSearchResults),
              subtitle: context.translate(
                LanguageLabelKeys.noSearchResultsSubtitle,
              ),
            );
          }
          final cubit = context.read<SearchProductCubit>();
          final isUnfiltered = cubit.currentFilters.query.isEmpty;
          final showRecent = isUnfiltered && cubit.recentSearches.isNotEmpty;
          final listingView = ProductListingView(
            products: state.data,
            isGrid: _isGrid,
            isFetchingMore: state.isFetchingMore,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom,
              start: ThemeConstants.paddingL,
              end: ThemeConstants.paddingL,
              top: showRecent || isUnfiltered
                  ? ThemeConstants.paddingXL
                  : ThemeConstants.paddingM,
            ),
            onProductTap: (_) =>
                cubit.saveImplicitSearch(_searchController.text),
          );
          return _pager.attach(
            SingleChildScrollView(
              controller: _pager.controller,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  if (showRecent)
                    RecentSearchesView(
                      key: ValueKey(_titleWaveTrigger),
                      recentSearches: cubit.recentSearches,
                      onTap: _onRecentSearchTap,
                      onRemove: (q) => cubit.removeRecentSearch(q),
                      onClearAll: () => cubit.clearRecentSearches(),
                    ),
                  if (isUnfiltered &&
                      (widget.searchSuggestions?.isNotEmpty ?? false))
                    TrendingSearchesView(
                      titleKey: ValueKey(_titleWaveTrigger),
                      trendingSearches: widget.searchSuggestions!,
                      onTap: _onRecentSearchTap,
                    ),
                  if (isUnfiltered)
                    SearchWishlistSection(
                      titleKey: ValueKey(_titleWaveTrigger),
                    ),
                  if (isUnfiltered)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: ThemeConstants.paddingL,
                        end: ThemeConstants.paddingL,
                        top: ThemeConstants.paddingXL,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: WaveText(
                          key: ValueKey(_titleWaveTrigger),
                          context.translate(LanguageLabelKeys.whatsOnYourMind),
                          style: context.tt.bodyLarge?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  listingView,
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
