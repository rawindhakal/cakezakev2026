import 'dart:async';
import 'dart:ui' as ui;

import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/localization/cubit/language_cubit.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/category/cubit/category_cubit.dart';
import 'package:customer/features/category/screens/category_screen.dart';
import 'package:customer/features/favourite/cubit/favorite_cubit.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/home/cubits/home_layout_cubit.dart';
import 'package:customer/features/home/screens/home_screen.dart';
import 'package:customer/features/main/models/bottom_navigation.dart';
import 'package:customer/features/main/widgets/bottom_navigation.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/main/widgets/floating_cart_bar.dart';
import 'package:customer/features/orders/screens/orders_screen.dart';
import 'package:customer/features/profile/screens/profile_screen.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/nav_cubit.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/theme/cubit/theme_cubit.dart';
import 'package:customer/core/theme/theme_switch_overlay.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();

  /// Triggers the circular theme-reveal animation: a snapshot
  /// of the current UI is punched with a growing transparent hole from
  /// [position], exposing the already-switched [newTheme] underneath.
  ///
  /// The returned future resolves once the heavy tab rebuild the theme
  /// switch triggers has had its first frame painted — callers that also
  /// animate (e.g. the toggle icon's rotation) should wait for it before
  /// starting, so their animation doesn't begin ticking right as that
  /// rebuild's jank hits and freeze partway through.
  static Future<void> changeTheme(
    BuildContext context, {
    required ThemeMode newTheme,
    required Offset position,
  }) async {
    await context.findAncestorStateOfType<_MainScreenState>()?._changeTheme(
      newTheme,
      position,
    );
  }
}

class _MainScreenState extends State<MainScreen> {
  final _shellBoundaryKey = GlobalKey();

  // Theme-reveal animation state (mirrors animation_theme.dart's MyApp).
  Offset? _animationPosition;
  ui.Image? _oldSnapshot;
  ThemeMode? _pendingTheme;
  bool _isAnimating = false;

  Future<void> _changeTheme(ThemeMode newTheme, Offset position) async {
    final themeCubit = context.read<ThemeCubit>();
    if (themeCubit.state.themeMode == newTheme || _isAnimating) return;

    final boundary =
        _shellBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    final oldSnapshot = await boundary?.toImage(
      pixelRatio: MediaQuery.of(context).devicePixelRatio,
    );
    if (!mounted || oldSnapshot == null) return;

    // Switch the real tree to the new theme immediately — it renders live
    // underneath the old snapshot for the whole animation, so the reveal
    // always shows real content, never a flat placeholder color.
    if (newTheme == ThemeMode.dark) {
      themeCubit.setDark();
    } else {
      themeCubit.setLight();
    }

    setState(() {
      _animationPosition = position;
      _oldSnapshot = oldSnapshot;
      _pendingTheme = newTheme;
      _isAnimating = true;
    });

    // Let the rebuild this setState just triggered actually paint before
    // handing control back — see the doc comment on the static [changeTheme].
    final settled = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!settled.isCompleted) settled.complete();
    });
    await settled.future;
  }

  void _finishAnimation() {
    setState(() {
      _isAnimating = false;
      _animationPosition = null;
      _oldSnapshot?.dispose();
      _oldSnapshot = null;
      _pendingTheme = null;
    });
  }

  // Bottom nav hides on scroll down, shows on scroll up (and at list edges
  // or on tab switch). A notifier keeps the rebuild to the nav/cart bar only.
  final _navVisible = ValueNotifier<bool>(true);

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse) {
        _navVisible.value = false;
      } else if (n.direction == ScrollDirection.forward) {
        _navVisible.value = true;
      }
    } else if (n is ScrollUpdateNotification) {
      final m = n.metrics;
      if (m.pixels <= m.minScrollExtent || m.pixels >= m.maxScrollExtent) {
        _navVisible.value = true;
      }
    }
    return false;
  }

  final _quickHomeLayoutCubit = QuickHomeLayoutCubit();
  final _ecommerceHomeLayoutCubit = EcommerceHomeLayoutCubit();
  final _categoryCubit = CategoryCubit();
  late final _screens = [
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _quickHomeLayoutCubit),
        BlocProvider.value(value: _ecommerceHomeLayoutCubit),
      ],
      child: const HomeScreen(),
    ),
    BlocProvider.value(value: _categoryCubit, child: const CategoryScreen()),
    const OrdersScreen(),
    const ProfileScreen(),
  ];

  static List<BottomNavItem> _navItems(BuildContext context) => [
    BottomNavItem(
      label: context.translate(LanguageLabelKeys.home),
      activeIconPath: AssetsConstants.homeActiveIcon,
      inactiveIconPath: AssetsConstants.homeInActiveIcon,
    ),
    BottomNavItem(
      label: context.translate(LanguageLabelKeys.categories),
      activeIconPath: AssetsConstants.categoryActiveIcon,
      inactiveIconPath: AssetsConstants.categoryInActiveIcon,
    ),
    BottomNavItem(
      label: context.translate(LanguageLabelKeys.orders),
      activeIconPath: AssetsConstants.orderActiveIcon,
      inactiveIconPath: AssetsConstants.orderInActiveIcon,
    ),
    BottomNavItem(
      label: context.translate(LanguageLabelKeys.profile),
      activeIconPath: AssetsConstants.profileActiveIcon,
      inactiveIconPath: AssetsConstants.profileInActiveIcon,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (AuthHiveBox.instance.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CartCubit>().loadFromApi();
      });
    }
  }

  @override
  void dispose() {
    _navVisible.dispose();
    _quickHomeLayoutCubit.close();
    _ecommerceHomeLayoutCubit.close();
    _categoryCubit.close();
    _oldSnapshot?.dispose();
    super.dispose();
  }

  void _reloadOnLanguageChange() {
    // Reload the channel on screen; the other one is just dropped and
    // refetches in the new language when the user switches to it.
    final isEcommerce =
        SettingsHiveBox.instance.channel == AppConstants.ecommerce;
    final active = isEcommerce
        ? _ecommerceHomeLayoutCubit
        : _quickHomeLayoutCubit;
    final inactive = isEcommerce
        ? _quickHomeLayoutCubit
        : _ecommerceHomeLayoutCubit;
    inactive.reset();
    active.loadHomeLayout();
    _categoryCubit.loadCategories();
    if (AuthHiveBox.instance.isLoggedIn) {
      context.read<FavoriteCubit>().loadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(key: _shellBoundaryKey, child: _buildShell(context)),

        // Covers the whole shell (tab content + bottom nav bar) so the
        // punched-hole reveal sweeps over everything, same as
        // animation_theme.dart's sample.
        if (_isAnimating &&
            _animationPosition != null &&
            _oldSnapshot != null &&
            _pendingTheme != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ThemeRevealAnimation(
                position: _animationPosition!,
                oldSnapshot: _oldSnapshot!,
                targetTheme: _pendingTheme!,
                onComplete: _finishAnimation,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShell(BuildContext context) {
    // The offline state is layered *over* the shell rather than replacing it:
    // rebuilding this subtree would recreate NavCubit (resetting the tab back
    // to Home) and tear down all four tab screens, losing their scroll and
    // pagination state every time the network blips.
    return BlocProvider(
      create: (_) => NavCubit(),
      child: BlocListener<LanguageCubit, LanguageState>(
        listenWhen: (previous, current) =>
            previous is LanguageLoaded &&
            current is LanguageLoaded &&
            previous.selectedId != current.selectedId,
        listener: (context, state) => _reloadOnLanguageChange(),
        child: BlocBuilder<NavCubit, NavState>(
          builder: (context, state) {
            return BlocBuilder<ConnectivityCubit, ConnectivityState>(
              builder: (context, connectivityState) {
                final isOffline = connectivityState is ConnectivityDisconnected;
                // Read here, outside the Scaffold: inside its body, extendBody
                // folds the nav bar height into MediaQuery's bottom padding,
                // which would double-count it and float the cart bar too high.
                final systemBottomInset = context.bottomSafePadding;
                return PopScope(
                  canPop: state.currentIndex == 0,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                    context.read<NavCubit>().changeTab(0);
                  },
                  child: AppScaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    applyBottomInset: false,
                    body: Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: IndexedStack(
                            index: state.currentIndex,
                            children: _screens,
                          ),
                        ),
                        if (state.currentIndex != 2 && state.currentIndex != 3)
                          ValueListenableBuilder<bool>(
                            valueListenable: _navVisible,
                            builder: (context, visible, child) =>
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  bottom:
                                      (visible
                                          ? ThemeConstants.bottomBarHeight
                                          : 0) +
                                      systemBottomInset,
                                  left: 0,
                                  right: 0,
                                  child: child!,
                                ),
                            child: FloatingCartBar(
                              onViewCart: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.checkout,
                              ),
                            ),
                          ),
                        // Last child so it covers the tab content and the floating
                        // cart bar, while the bottom nav (outside the body) stays
                        // reachable.
                        if (isOffline)
                          const Positioned.fill(child: AppNoInternetView()),
                      ],
                    ),
                    bottomNavigationBar: ValueListenableBuilder<bool>(
                      valueListenable: _navVisible,
                      builder: (context, visible, child) => AnimatedSlide(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        offset: visible ? Offset.zero : const Offset(0, 1),
                        child: child,
                      ),
                      child: BottomNavBar(
                        currentIndex: state.currentIndex,
                        onTap: (i) {
                          _navVisible.value = true;
                          context.read<NavCubit>().changeTab(i);
                        },
                        items: _navItems(context),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
