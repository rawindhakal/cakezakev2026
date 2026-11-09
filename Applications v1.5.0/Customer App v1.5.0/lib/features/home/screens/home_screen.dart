import 'package:customer/commons/widgets/demo_data_disclaimer.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_selection_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/screens/sub_category_screen.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/services/notification_service.dart';
import 'package:customer/features/address/widgets/location_permission_dialog.dart';
import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/commons/cubit/location_cubit.dart';
import 'package:customer/features/home/cubits/home_layout_cubit.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/models/enums/home_type.dart';
import 'package:customer/features/home/utils/home_hex_color.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/home/widgets/back_to_top_button.dart';
import 'package:customer/features/home/widgets/home_app_bar_delegate.dart';
import 'package:customer/features/location/widgets/location_required_view.dart';
import 'package:customer/commons/widgets/popup_dialog.dart';
import 'package:customer/features/home/widgets/section_widget.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_dialog.dart';
import 'package:customer/features/home/widgets/skeleton_loader.dart';
import 'package:customer/commons/widgets/store_closed_banner.dart';
import 'package:customer/features/location/screens/location_search_screen.dart';
import 'package:customer/features/location/screens/location_setup_sheet.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/screens/product_screen.dart';
import 'package:customer/features/main/cubit/nav_cubit.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';

List<Color> _defaultGradient(ThemeData theme) {
  final primary = theme.primaryColor;
  return [primary, primary];
}

/// Header/tab state of one channel, kept while the other channel is shown.
class _ChannelHeader {
  final String layoutMode;
  final HomeType homeType;
  final Layout? layout;
  final String? timeToDeliver;
  final String? distance;
  final String? channelLabelQuick;
  final String? channelLabelEcommerce;
  final List<String>? searchSuggestions;
  final List<CategoryTabs> categoryTabs;
  final int tabIndex;

  const _ChannelHeader({
    required this.layoutMode,
    required this.homeType,
    required this.layout,
    required this.timeToDeliver,
    required this.distance,
    required this.channelLabelQuick,
    required this.channelLabelEcommerce,
    required this.searchSuggestions,
    required this.categoryTabs,
    required this.tabIndex,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  TabController? _tabController;

  // Toggle position shown in the header (flips instantly on tap).
  int _selectedMode = 0;
  // Channel whose cubit drives the body — trails _selectedMode until pending
  // cart syncs of the old channel are flushed.
  int _bodyMode = 0;
  // Channel the header fields below were last filled from (null = none).
  int? _headerMode;
  // Header/tabs of a channel switched away from, restored when switching
  // back while its cubit still holds the loaded layout.
  final Map<int, _ChannelHeader> _headerByMode = {};
  final ValueNotifier<bool> _isScrolled = ValueNotifier(false);
  double _lastScrollOffset = 0;
  List<CategoryTabs> _categoryTabs = [];
  bool _resetTabsOnNextLoad = false;
  String _layoutMode = '';
  HomeType _homeType = HomeType.unknown;
  Layout? _layout;
  String? _timeToDeliver;
  String? _distance;
  String? _channelLabelQuick;
  String? _channelLabelEcommerce;
  List<String>? _searchSuggestions;

  static const double _kScrollThreshold = 80.0;

  final Expando<Widget> _sectionWidgets = Expando();

  List<Color> _gradient(ThemeData theme) => _defaultGradient(theme);

  static int _modeOf(String channel) =>
      channel == AppConstants.ecommerce ? 1 : 0;

  HomeLayoutCubit _cubitFor(int mode) => mode == 1
      ? context.read<EcommerceHomeLayoutCubit>()
      : context.read<QuickHomeLayoutCubit>();

  HomeLayoutCubit get _activeCubit => _cubitFor(_bodyMode);

  void _saveHeader() {
    if (_headerMode != _bodyMode) return;
    _headerByMode[_bodyMode] = _ChannelHeader(
      layoutMode: _layoutMode,
      homeType: _homeType,
      layout: _layout,
      timeToDeliver: _timeToDeliver,
      distance: _distance,
      channelLabelQuick: _channelLabelQuick,
      channelLabelEcommerce: _channelLabelEcommerce,
      searchSuggestions: _searchSuggestions,
      categoryTabs: _categoryTabs,
      tabIndex: _tabController?.index ?? 0,
    );
  }

  // Must be called inside setState. Returns the replaced controller, to be
  // disposed after the frame.
  TabController? _restoreHeader(int mode, _ChannelHeader h) {
    final old = _tabController;
    _layoutMode = h.layoutMode;
    _homeType = h.homeType;
    _layout = h.layout;
    _timeToDeliver = h.timeToDeliver;
    _distance = h.distance;
    _channelLabelQuick = h.channelLabelQuick;
    _channelLabelEcommerce = h.channelLabelEcommerce;
    _searchSuggestions = h.searchSuggestions;
    _categoryTabs = h.categoryTabs;
    _tabController = h.categoryTabs.isEmpty
        ? null
        : _makeTabController(
            h.categoryTabs.length,
            initialIndex: h.tabIndex.clamp(0, h.categoryTabs.length - 1),
          );
    _headerMode = mode;
    _resetTabsOnNextLoad = false;
    return old;
  }

  // Mirrors HomeAppBarDelegate's own background resolution so the
  // pull-to-refresh spinner matches whatever the header is currently
  // showing (per-tab brand color / single-layout color) instead of
  // always defaulting to the theme's primary color.
  Color _currentHeaderColor(ThemeData theme) {
    if (_homeType == HomeType.single) {
      return parseHomeHexColor(_layout?.backgroundColor) ?? theme.primaryColor;
    }
    final idx = _tabController?.index ?? 0;
    final tab = (_categoryTabs.isNotEmpty && idx < _categoryTabs.length)
        ? _categoryTabs[idx]
        : null;
    return parseHomeHexColor(tab?.backgroundColor) ?? theme.primaryColor;
  }

  String _locationLabel = '';
  String _locationAddress = '';
  bool _isCheckingPermission = false;

  void _loadLocation() {
    final hive = SettingsHiveBox.instance;
    setState(() {
      _locationLabel = hive.locationLabel.isNotEmpty
          ? hive.locationLabel
          : context.translate(LanguageLabelKeys.setLocation);
      _locationAddress = hive.locationAddress;
    });
  }

  /// Everything a location pick can change — compared before/after the
  /// sheet so dismissing it untouched doesn't reload every tab.
  String _locationSessionKey() {
    final hive = SettingsHiveBox.instance;
    return [
      hive.userLatitude,
      hive.userLongitude,
      hive.zoneId,
      hive.channel,
    ].join('|');
  }

  Future<void> _openLocationSheet() async {
    final before = _locationSessionKey();
    await showLocationSetupSheet(context);
    if (!mounted) return;
    _loadLocation();
    if (_locationSessionKey() != before) _refreshAfterLocationChange();
  }

  Future<void> _openLocationSearch() async {
    final saved = await AppNavigator.push<bool>(
      context,
      const LocationSearchScreen(),
    );
    if (!mounted) return;
    _loadLocation();
    if (saved == true) _refreshAfterLocationChange();
  }

  void _onLocationConfirmed() {
    _loadLocation();
    _refreshAfterLocationChange();
  }

  /// Session (zone/location/channel) is already saved by the picker — sync
  /// the channel toggle to it, then re-call every location-dependent API.
  void _refreshAfterLocationChange() {
    if (!mounted || !SettingsHiveBox.instance.hasLocation) return;
    final mode = _modeOf(SettingsHiveBox.instance.channel);
    // New location = both channels' layouts are stale; the hidden one just
    // refetches when switched to.
    _headerByMode.clear();
    _cubitFor(1 - mode).reset();
    if (mode != _bodyMode || mode != _selectedMode) {
      // New channel = different catalog — drop the old tabs/sections so the
      // skeleton shows instead of the previous channel's stale layout.
      final old = _tabController;
      setState(() {
        _selectedMode = mode;
        _bodyMode = mode;
        _headerMode = null;
        _categoryTabs = [];
        _tabController = null;
        _layout = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    }
    _activeCubit.loadHomeLayout(emitLoadingState: true);
    context.read<LocationCubit>().notifyLocationChanged();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    if (_isCheckingPermission || !mounted) return;
    _isCheckingPermission = true;
    try {
      var permission = await Geolocator.checkPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }

      if (permission == LocationPermission.deniedForever) {
        await showLocationPermissionDialog(context);
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (!SettingsHiveBox.instance.hasLocation) {
          await _openLocationSheet();
        }
      }
    } finally {
      _isCheckingPermission = false;
    }
  }

  // Guards against the spin wheel modal covering the home screen while
  // loadHomeLayout (fired in initState) is still in flight — waits for it
  // to resolve (loaded or errored) before the wheel shows, capped so a
  // slow/hung request can't block the wheel indefinitely.
  Future<void> _waitForHomeLayoutReady([HomeLayoutCubit? target]) async {
    final cubit = target ?? _activeCubit;
    if (cubit.state is HomeLayoutLoaded || cubit.state is HomeLayoutError) {
      return;
    }
    await cubit.stream
        .firstWhere((s) => s is HomeLayoutLoaded || s is HomeLayoutError)
        .timeout(const Duration(seconds: 5), onTimeout: () => cubit.state);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadLocation();
    _selectedMode = _modeOf(SettingsHiveBox.instance.channel);
    _bodyMode = _selectedMode;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _activeCubit.loadHomeLayout(emitLoadingState: true);
      }
      if (!mounted) return;
      await _checkAndRequestLocationPermission();
      if (!mounted) return;
      await NotificationService.instance.requestPermission();
      if (!mounted) return;
      await PopupDialog.maybeShow(context);
      if (!mounted) return;
      await _waitForHomeLayoutReady();
      if (mounted) SpinWheelDialog.maybeShow(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocation();
  }

  // Mirrors HomeAppBarDelegate.minExtent (topPadding + _searchH) so the
  // floating button sits flush under the pinned header regardless of
  // whether category tabs are showing.
  double _headerMinExtent(BuildContext context) {
    final topPadding = context.topSafePadding;
    final screenHeight = context.screenHeight;
    final searchH = _categoryTabs.isEmpty
        ? screenHeight * 0.045 + 22
        : screenHeight * 0.1075 + 40;
    return topPadding + searchH;
  }

  // Fires loadMoreSections once 70% of the section list is scrolled
  // (30% of scroll extent remaining), not just near the physical bottom.
  static const double _kLoadMoreTriggerFraction = 0.7;

  void _onScroll() {
    final offset = _scrollController.offset;
    final scrollingUp = offset < _lastScrollOffset;
    _lastScrollOffset = offset;

    final shouldShow = offset > _kScrollThreshold && scrollingUp;
    if (shouldShow != _isScrolled.value) _isScrolled.value = shouldShow;

    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent > 0 && offset >= maxExtent * _kLoadMoreTriggerFraction) {
      _activeCubit.loadMoreSections();
    }
  }

  String? _categoryIdAt(int index) {
    if (_homeType != HomeType.categoryWise) return null;
    if (_categoryTabs.isEmpty || index >= _categoryTabs.length) return null;
    // null id — no category filter
    return _categoryTabs[index].id;
  }

  // Data load + scroll-to-top for category switches are handled by
  // HomeAppBarDelegate.onCategoryTabTap (fires immediately on tap), not
  // here — a controller listener only fires after the tab indicator's
  // switch animation settles (~300ms later), which reads as a lag.
  TabController _makeTabController(int count, {int initialIndex = 0}) {
    return TabController(
      length: count,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _tabController?.dispose();
    _isScrolled.dispose();
    super.dispose();
  }

  Widget _buildSections(
    BuildContext context,
    List<Sections> sections, {
    bool isLoadingMore = false,
  }) {
    // Lazy list: only sections on (or near) screen are built and laid out.
    // A single Column here built every section — and started every image
    // load — up front, which made the first frame after load janky.
    // ObjectKey keeps each section's state (carousel page, tab) through
    // load-more appends, and resets it when a reload brings new objects.
    final footer = <Widget>[
      if (isLoadingMore) const SkeletonLoader(),
      BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final demoMode = state is SettingsLoaded
              ? state.settings.data?.demoMode
              : SettingsHiveBox.instance.getAppSettings()?.demoMode;
          final isDemo = demoMode == "1" || demoMode?.toLowerCase() == "true";
          return isDemo ? const DemoDataDisclaimer() : const SizedBox.shrink();
        },
      ),
      // The safe-area inset is only needed when the floating cart bar sits
      // above the bottom nav — without it the bar would cover the last row.
      BlocBuilder<CartCubit, CartState>(
        buildWhen: (prev, curr) =>
            (prev.totalItems > 0) != (curr.totalItems > 0),
        builder: (context, cartState) => SizedBox(
          height:
              ThemeConstants.bottomBarHeight +
              (cartState.totalItems > 0
                  ? context.bottomSafePadding
                  : context.bottomSafePadding / 2),
        ),
      ),
    ];
    return SliverList.builder(
      itemCount: sections.length + footer.length,
      itemBuilder: (_, index) {
        if (index >= sections.length) return footer[index - sections.length];
        final s = sections[index];
        // Same instance per section object → a load-more rebuild of this
        // list skips every already-built section instead of re-running
        // their whole product-card subtrees.
        return _sectionWidgets[s] ??= _buildSection(s);
      },
    );
  }

  Widget _buildSection(Sections s) {
    return SectionWidget(
      key: ObjectKey(s),
      section: s,
      onCategoryTap: (cat) {
        if (cat.id == null) return;
        final category = Category(
          id: cat.id.toString(),
          name: cat.name,
          imageUrl: cat.imageUrl,
          hasChild: cat.hasChild ?? false,
        );
        if (category.hasChild == true) {
          AppNavigator.push(
            context,
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      SubCategoryCubit(parentCategoryId: category.id!),
                ),
                BlocProvider(create: (_) => SubCategorySelectionCubit()),
                BlocProvider(create: (_) => SubCategoryChildrenCubit()),
                BlocProvider(create: (_) => ProductCubit()),
                BlocProvider(create: (_) => FilterCubit()),
              ],
              child: SubCategoryScreen(parentCategory: category),
            ),
          );
        } else {
          AppNavigator.push(
            context,
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      SubCategoryCubit(parentCategoryId: category.id!),
                ),
                BlocProvider(
                  create: (_) =>
                      ProductCubit()..loadProducts(categoryId: category.id!),
                ),
                BlocProvider(
                  create: (_) =>
                      FilterCubit()..loadFilters(categoryId: category.id!),
                ),
              ],
              child: SubCategoryScreen(
                parentCategory: category,
                showSidebar: false,
              ),
            ),
          );
        }
      },
      onProductTap: (product) {
        if (product.id != null) {
          AppNavigator.pushNamed(
            context,
            RouteNames.productDetail,
            arguments: product.id,
          );
        }
      },
      onBrandTap: (brand) {
        if (brand.id == null) return;
        AppNavigator.push(
          context,
          BlocProvider(
            create: (_) => ProductCubit(),
            child: ProductScreen(
              title: brand.name?.isNotEmpty == true
                  ? brand.name!
                  : context.translate(LanguageLabelKeys.brand),
              brandId: brand.id.toString(),
            ),
          ),
        );
      },
      onViewMoreTap: (title, scope) {
        AppNavigator.push(
          context,
          BlocProvider(
            create: (_) => ProductCubit(),
            child: ProductScreen(
              title: title.isNotEmpty
                  ? title
                  : context.translate(LanguageLabelKeys.products),
              categoryId: scope.categoryIds,
              dataSource: scope.dataSource,
              manualProductIds: scope.manualProductIds,
              scopeBrandIds: scope.brandIds,
              filterMode: scope.filterMode,
            ),
          ),
        );
      },
    );
  }

  // Applies a state emitted by the cubit currently driving the body.
  void _onLayoutState(HomeLayoutCubit cubit, HomeLayoutState state) {
    if (state is HomeLayoutLoaded || state is HomeLayoutError) {
      context.read<CountrySettingsCubit>().loadCountrySettings(force: true);
    }
    if (state is HomeLayoutError) {
      // Drop stale sections so a retry's loading state doesn't flash
      // the previous (now invalid) layout before the error re-shows.
      setState(() => _layout = null);
    }
    if (state is HomeLayoutLoaded) {
      final data = state.homeLayout.data;
      if (cubit.channel == AppConstants.quick) {
        SettingsHiveBox.instance.setStoreClosed(data?.branchClosed ?? 0);
      }
      // Server declares a single available mode (not "both") — sync the
      // persisted channel to match so the header stays consistent with
      // what the API actually served, since the toggle is hidden here
      // and can't let the user correct a stale channel manually.
      final availableModes = data?.availableModes;
      if ((availableModes == AppConstants.quick ||
              availableModes == AppConstants.ecommerce) &&
          cubit.channel != availableModes) {
        SettingsHiveBox.instance.setChannel(availableModes!);
        // This layout was served for the wrong channel — hand the body to
        // the server's channel cubit and load it there instead.
        final mode = _modeOf(availableModes);
        _saveHeader();
        setState(() {
          _selectedMode = mode;
          _bodyMode = mode;
          _resetTabsOnNextLoad = true;
        });
        final target = _activeCubit;
        if (target.state is! HomeLayoutLoading) target.loadHomeLayout();
        return;
      }
      // A category-tab load only swaps the sections — keep the tab bar
      // already on screen (the filtered response may send different
      // or empty tabs, which would rebuild/reset or hide the bar).
      final isCategoryLoad =
          !_resetTabsOnNextLoad &&
          cubit.currentCategoryId != null &&
          _categoryTabs.isNotEmpty;
      final tabs = isCategoryLoad ? _categoryTabs : (data?.categoryTabs ?? []);
      final old = _tabController;
      if (tabs.isNotEmpty) {
        // Channel switch: rebuild the controller even if the tab count
        // matches, else the old channel's selected index carries over.
        final needNew =
            old == null || old.length != tabs.length || _resetTabsOnNextLoad;
        _resetTabsOnNextLoad = false;
        final newCtrl = needNew ? _makeTabController(tabs.length) : old;
        setState(() {
          _layoutMode = data?.availableModes ?? '';
          _homeType = HomeType.fromRaw(data?.homeType);
          _layout = data?.layout;
          _timeToDeliver = data?.timeToDeliver;
          _distance = data?.distance;
          _channelLabelQuick = data?.quickButtonLabel;
          _channelLabelEcommerce = data?.ecommerceButtonLabel;
          _searchSuggestions = data?.searchSuggestions;
          _categoryTabs = tabs;
          _tabController = newCtrl;
          _headerMode = _modeOf(cubit.channel);
        });
        if (needNew) {
          WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
          // If first tab is a specific category (not "All"/null id), reload content filtered by it
          final firstTabId = tabs.isNotEmpty ? tabs.first.id : null;
          if (firstTabId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && identical(cubit, _activeCubit)) {
                cubit.loadHomeLayout(categoryId: firstTabId);
              }
            });
          }
        }
      } else {
        _resetTabsOnNextLoad = false;
        setState(() {
          _layoutMode = data?.availableModes ?? '';
          _homeType = HomeType.fromRaw(data?.homeType);
          _layout = data?.layout;
          _timeToDeliver = data?.timeToDeliver;
          _distance = data?.distance;
          _channelLabelQuick = data?.quickButtonLabel;
          _channelLabelEcommerce = data?.ecommerceButtonLabel;
          _searchSuggestions = data?.searchSuggestions;
          _tabController = null;
          _categoryTabs = [];
          _headerMode = _modeOf(cubit.channel);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
      }
    }
  }

  // Load-more emits Loaded→Loaded with the same homeLayout object (only
  // sections appended) — skip those, else every page fetched mid-scroll
  // setStates the whole screen and re-calls country settings. States of
  // the hidden channel's cubit are ignored until it is switched to.
  bool _shouldHandle(
    HomeLayoutCubit cubit,
    HomeLayoutState prev,
    HomeLayoutState curr,
  ) =>
      identical(cubit, _activeCubit) &&
      !(prev is HomeLayoutLoaded &&
          curr is HomeLayoutLoaded &&
          identical(prev.homeLayout, curr.homeLayout));

  @override
  Widget build(BuildContext context) {
    final hasLocation = SettingsHiveBox.instance.hasLocation;

    if (!hasLocation) {
      return BlocListener<NavCubit, NavState>(
        listenWhen: (prev, curr) =>
            curr.currentIndex == 0 && prev.currentIndex != 0,
        listener: (context, state) {
          if (!SettingsHiveBox.instance.hasLocation && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openLocationSheet();
            });
          }
        },
        child: LocationRequiredView(
          onSetLocation: _openLocationSheet,
          onSearchManually: _openLocationSearch,
          onLocationConfirmed: _onLocationConfirmed,
        ),
      );
    }

    final g = _gradient(Theme.of(context));
    return MultiBlocListener(
      listeners: [
        BlocListener<QuickHomeLayoutCubit, HomeLayoutState>(
          listenWhen: (prev, curr) =>
              _shouldHandle(context.read<QuickHomeLayoutCubit>(), prev, curr),
          listener: (context, state) =>
              _onLayoutState(context.read<QuickHomeLayoutCubit>(), state),
        ),
        BlocListener<EcommerceHomeLayoutCubit, HomeLayoutState>(
          listenWhen: (prev, curr) => _shouldHandle(
            context.read<EcommerceHomeLayoutCubit>(),
            prev,
            curr,
          ),
          listener: (context, state) =>
              _onLayoutState(context.read<EcommerceHomeLayoutCubit>(), state),
        ),
      ],
      child: AppScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        applyBottomInset: false,
        body: Stack(
          children: [
            RefreshIndicator(
              color: _currentHeaderColor(Theme.of(context)),
              onRefresh: () async {
                final idx = _tabController?.index ?? 0;
                final cartCubit = context.read<CartCubit>();
                // Current sections stay on screen; the spinner ends when
                // the new layout lands.
                await _activeCubit.loadHomeLayout(
                  categoryId: _categoryIdAt(idx),
                );
                if (AuthHiveBox.instance.isLoggedIn) {
                  cartCubit.loadFromApi();
                }
              },
              child: _buildScrollView(context, g),
            ),
            Positioned(
              top: _headerMinExtent(context) + ThemeConstants.paddingS,
              left: 0,
              right: 0,
              child: Center(
                child: BackToTopButton(
                  visibleListenable: _isScrolled,
                  onTap: () {
                    if (!_scrollController.hasClients) return;
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollView(BuildContext context, List<Color> g) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: HomeAppBarDelegate(
            gradient: g,
            categoryTabs: _categoryTabs,
            tabController: _tabController,
            selectedMode: _selectedMode,
            onModeChanged: (i) async {
              if (i == _selectedMode) return;
              // Toggle flips now; the body keeps the current channel until
              // pending cart syncs are flushed below.
              setState(() => _selectedMode = i);
              final cartActionCubit = context.read<CartActionCubit>();
              final cartCubit = context.read<CartCubit>();
              final countrySettingsCubit = context.read<CountrySettingsCubit>();
              // Drain any debounced add/remove syncs under the OLD
              // channel before switching — otherwise a pending request
              // fires later with the NEW channel header against a
              // product from the old catalog ("item not found").
              await cartActionCubit.flushAllPending();
              // Toggled back (or again) while flushing — the latest tap's
              // call does the switch.
              if (!mounted || _selectedMode != i || _bodyMode == i) return;
              final ch = i == 1 ? AppConstants.ecommerce : AppConstants.quick;
              SettingsHiveBox.instance.setChannel(ch);
              _saveHeader();
              final target = _cubitFor(i);
              final targetState = target.state;
              final saved = _headerByMode[i];
              // Target channel still holds its layout — show it (and its
              // header/tabs) instantly instead of refetching.
              final restore =
                  saved != null &&
                  (targetState is HomeLayoutLoaded ||
                      targetState is HomeLayoutLoading);
              TabController? oldCtrl;
              // Otherwise keep the current header/tabs/sections on screen
              // until the new channel's layout arrives (the Loaded handler
              // replaces them) — clearing here flashed the default header
              // gradient.
              setState(() {
                _bodyMode = i;
                if (restore) {
                  oldCtrl = _restoreHeader(i, saved);
                } else {
                  _resetTabsOnNextLoad = true;
                }
              });
              if (restore) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => oldCtrl?.dispose(),
                );
                countrySettingsCubit.loadCountrySettings(force: true);
              }
              final Future<void> ready;
              if (targetState is HomeLayoutInitial ||
                  targetState is HomeLayoutError) {
                ready = target.loadHomeLayout(
                  emitLoadingState: targetState is HomeLayoutError,
                );
              } else {
                // Loaded in the background but never shown — apply it now.
                if (!restore && targetState is HomeLayoutLoaded) {
                  _onLayoutState(target, targetState);
                }
                ready = _waitForHomeLayoutReady(target);
              }
              if (AuthHiveBox.instance.isLoggedIn) {
                cartCubit.resetForChannelSwitch();
                ready.then((_) => cartCubit.loadFromApi());
              } else {
                cartCubit.switchChannel(ch);
              }
            },
            onCategoryTabTap: (i) {
              if (_isScrolled.value && _scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
              // Re-tapping the tab already shown/loading — keep its
              // layout, no API recall (still retry after an error).
              final homeLayoutCubit = _activeCubit;
              if (homeLayoutCubit.state is! HomeLayoutError &&
                  homeLayoutCubit.state is! HomeLayoutInitial &&
                  _categoryIdAt(i) == homeLayoutCubit.currentCategoryId) {
                return;
              }
              // Fires immediately on tap — waiting for the tab
              // indicator animation (controller listener) to settle
              // added a visible ~300ms delay before the skeleton
              // showed.
              // Rebuild only so the header picks up the new tab's colors;
              // current sections stay until the filtered layout arrives.
              setState(() {});
              homeLayoutCubit.loadHomeLayout(categoryId: _categoryIdAt(i));
            },
            topPadding: context.topSafePadding,
            screenHeight: context.screenHeight,
            textScaleFactor: MediaQuery.textScalerOf(context).scale(1.0),
            locationLabel: _locationLabel,
            locationAddress: _locationAddress,
            onLocationTap: _openLocationSheet,
            layoutMode: _layoutMode,
            homeType: _homeType,
            layout: _layout,
            timeToDeliver: _timeToDeliver,
            distance: _distance,
            channelLabelQuick: _channelLabelQuick,
            channelLabelEcommerce: _channelLabelEcommerce,
            searchSuggestions: _searchSuggestions,
            selectedTab: (() {
              final idx = _tabController?.index ?? 0;
              return (_categoryTabs.isNotEmpty && idx < _categoryTabs.length)
                  ? _categoryTabs[idx]
                  : null;
            })(),
          ),
        ),
        BlocBuilder<HomeLayoutCubit, HomeLayoutState>(
          bloc: _activeCubit,
          builder: (context, layoutState) {
            final sectionsEmpty =
                layoutState is HomeLayoutLoaded &&
                (layoutState.homeLayout.data?.layout?.sections ?? []).isEmpty;
            if (SettingsHiveBox.instance.isStoreClosedQuick && !sectionsEmpty) {
              return const SliverToBoxAdapter(child: StoreClosedBanner());
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        ),
        BlocBuilder<HomeLayoutCubit, HomeLayoutState>(
          bloc: _activeCubit,
          builder: (context, layoutState) {
            // Initial = a channel switched to but not fetched yet.
            if (layoutState is HomeLayoutLoading ||
                layoutState is HomeLayoutInitial) {
              final cachedSections = _layout?.sections ?? [];
              // A tab/category switch re-triggers loading — if we
              // already have a rendered layout, keep it on screen
              // instead of blanking out while the new one arrives.
              if (cachedSections.isNotEmpty) {
                return _buildSections(context, cachedSections);
              }
              return const SliverToBoxAdapter(child: SkeletonLoader());
            }
            if (layoutState is HomeLayoutError) {
              return SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: context.screenHeight * 0.6,
                  ),
                  child: Center(
                    child: EmptyStateWidget(
                      imagePath: AssetsConstants.noSearchFound,
                      title: layoutState.message,
                      subtitle: context.translate(
                        LanguageLabelKeys.pullToRefresh,
                      ),
                      onRetry: () {
                        final idx = _tabController?.index ?? 0;
                        _activeCubit.loadHomeLayout(
                          categoryId: _categoryIdAt(idx),
                          emitLoadingState: true,
                        );
                      },
                    ),
                  ),
                ),
              );
            }
            if (layoutState is HomeLayoutLoaded) {
              final sections =
                  layoutState.homeLayout.data?.layout?.sections ?? [];
              if (sections.isEmpty) {
                return SliverToBoxAdapter(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: context.screenHeight * 0.6,
                    ),
                    child: Center(
                      child: EmptyStateWidget(
                        imagePath: AssetsConstants.noSearchFound,
                        title: context.translate(
                          LanguageLabelKeys.noContentAvailable,
                        ),
                        subtitle: context.translate(
                          LanguageLabelKeys.contentCurrentlyUnavailable,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return _buildSections(
                context,
                sections,
                isLoadingMore: layoutState.isLoadingMore,
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        ),
      ],
    );
  }
}
