import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/services/notification_service.dart';
import 'package:deliveryboy/core/theme/cubit/theme_cubit.dart';
import 'package:deliveryboy/core/theme/theme_switch_overlay.dart';
import 'package:deliveryboy/features/auth/cubit/add_fcm_token_cubit.dart';
import 'package:deliveryboy/features/home/cubit/dashboard_cubit.dart';
import 'package:deliveryboy/features/main/models/bottom_navigation.dart';
import 'package:deliveryboy/features/main/widgets/bottom_navigation.dart';
import 'package:deliveryboy/features/earnings/screens/earnings_screen.dart';
import 'package:deliveryboy/features/orders/cubit/order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_cubit.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/nav_cubit.dart';
import '../../home/screens/dashboard_screen.dart';
import '../../orders/screens/orders_screen.dart';
import '../../profile/screens/profile_screen.dart';

/// Root screen hosting the bottom-navigated Home/Orders/Earnings/Profile tabs.
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
    await context.findAncestorStateOfType<_MainScreenState>()?._changeTheme(newTheme, position);
  }
}

class _MainScreenState extends State<MainScreen> {
  static const _screens = [
    HomeScreen(),
    OrdersScreen(),
    EarningsScreen(),
    ProfileScreen(),
  ];

  final _shellBoundaryKey = GlobalKey();

  // Bottom nav hides on scroll down, shows on scroll up (and at list edges
  // or on tab switch). A notifier keeps the rebuild to the nav bar only.
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

  // Theme-reveal animation state (mirrors cakezake_customer's MainScreen).
  Offset? _animationPosition;
  ui.Image? _oldSnapshot;
  ThemeMode? _pendingTheme;
  bool _isAnimating = false;

  Future<void> _changeTheme(ThemeMode newTheme, Offset position) async {
    final themeCubit = context.read<ThemeCubit>();
    if (themeCubit.state.themeMode == newTheme || _isAnimating) return;

    final boundary = _shellBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final oldSnapshot = await boundary?.toImage(pixelRatio: MediaQuery.of(context).devicePixelRatio);
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

  @override
  void initState() {
    super.initState();
    _syncMissingFcmToken();
  }

  /// Login sends the FCM token along with the credentials, but that token can
  /// still be blank at that point (Firebase hadn't handed one out yet, or the
  /// fetch failed offline). In that case the session has no token registered
  /// server-side, and nothing else retries until the token rotates or the app
  /// is relaunched — so retry it here, once the user lands post-login.
  Future<void> _syncMissingFcmToken() async {
    final service = NotificationService.instance;
    if (AuthHiveBox.instance.fcmToken.isNotEmpty) return;
    final token = await service.getToken();
    if (token == null || token.isEmpty || !mounted) return;
    // Re-checked after the await: the service's own token sync may have landed
    // while Firebase was still resolving, which leaves nothing to do here.
    if (AuthHiveBox.instance.fcmToken.isNotEmpty) return;
    // Loses the race against the service's sync of the same token — that call
    // registers it, so firing a second identical one would be pure duplication.
    if (!service.beginTokenRegistration()) return;
    try {
      final cubit = context.read<AddFcmTokenCubit>();
      await cubit.addFcmToken(
        fcmToken: token,
        platform: Platform.isAndroid
            ? ApiParameters.android
            : ApiParameters.ios,
      );
      // Cached only on success: leaving the box blank after a failed call is
      // what makes NotificationService retry the registration on next launch.
      if (cubit.state is AddFcmTokenLoaded) {
        await AuthHiveBox.instance.setFcmToken(token);
      }
    } finally {
      service.endTokenRegistration();
    }
  }

  void _reloadOnLanguageChange() {
    context.read<DashboardCubit>().getDashboard();
    context.read<OrderCubit>().loadOrders();
    context.read<EcommerceOrderCubit>().loadOrders();
    context.read<ReturnOrderCubit>().loadOrders();
  }

  @override
  void dispose() {
    _navVisible.dispose();
    _oldSnapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(key: _shellBoundaryKey, child: _buildShell(context)),

        // Covers the whole shell (tab content + bottom nav bar) so the
        // punched-hole reveal sweeps over everything.
        if (_isAnimating && _animationPosition != null && _oldSnapshot != null && _pendingTheme != null)
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
    final navItems = [
      BottomNavItem(
        label: context.translate(LanguageLabelKeys.home),
        activeIconPath: AssetsConstants.homeActiveIcon,
        inactiveIconPath: AssetsConstants.homeInActiveIcon,
      ),
      BottomNavItem(
        label: context.translate(LanguageLabelKeys.myDelivery),
        activeIconPath: AssetsConstants.orderActiveIcon,
        inactiveIconPath: AssetsConstants.orderInActiveIcon,
      ),
      BottomNavItem(
        label: context.translate(LanguageLabelKeys.earnings),
        activeIconPath: AssetsConstants.walletActiveIcon,
        inactiveIconPath: AssetsConstants.walletInActiveIcon,
      ),
      BottomNavItem(
        label: context.translate(LanguageLabelKeys.profile),
        activeIconPath: AssetsConstants.profileActiveIcon,
        inactiveIconPath: AssetsConstants.profileInActiveIcon,
      ),
    ];

    // No connectivity gate here on purpose: each tab renders its own
    // no-internet state, which keeps the bottom bar reachable while offline and
    // preserves per-tab state (scroll position, filters, selected tab) instead
    // of tearing the whole IndexedStack down and rebuilding it on reconnect.
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
            return PopScope(
              canPop: state.currentIndex == 0,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                context.read<NavCubit>().changeTab(0);
              },
              child: AppScaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                applyBottomInset: false,
                body: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: IndexedStack(
                    index: state.currentIndex,
                    children: _screens,
                  ),
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
                    items: navItems,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
