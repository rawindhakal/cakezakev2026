import 'dart:async';

import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/theme/app_sizes.dart';
import 'package:customer/features/onboarding/models/onboarding_page_data.dart';
import 'package:customer/features/onboarding/widgets/onboarding_bottom_content.dart';
import 'package:customer/features/onboarding/widgets/onboarding_page_content.dart';
import 'package:customer/features/onboarding/widgets/onboarding_skip_button.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _autoPlayInterval = Duration(seconds: 2);
  static const _pageCount = 3;
  static const _loopMultiplier = 1000;
  static const _midLoop = _loopMultiplier ~/ 2 * _pageCount;

  final _pageCtrl = PageController(initialPage: _midLoop);
  int _current = 0;
  Timer? _autoPlayTimer;

  late final AnimationController _iconCtrl;
  List<OnboardingPageData> _pages = const [];

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _iconCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasEmpty = _pages.isEmpty;
    _pages = buildOnboardingPages(context);
    if (wasEmpty) _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (_) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int i) {
    setState(() => _current = i % _pageCount);
    _iconCtrl.reset();
    _iconCtrl.forward();
    _startAutoPlay();
  }

  void _next() {
    if (_current < _pageCount - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  // Get Started → login
  Future<void> _finish() async {
    await SettingsHiveBox.instance.setOnboardingSeen();
    if (!mounted) return;
    AppNavigator.pushReplacementNamed(context, RouteNames.login);
  }

  // Skip → main if location already set, else full-screen location gate first
  Future<void> _skip() async {
    await SettingsHiveBox.instance.setOnboardingSeen();
    if (!mounted) return;
    AppNavigator.pushReplacementNamed(
      context,
      SettingsHiveBox.instance.hasLocation
          ? RouteNames.main
          : RouteNames.locationRequired,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount: _pageCount * _loopMultiplier,
            itemBuilder: (_, i) => OnboardingPageContent(
              page: _pages[i % _pageCount],
              animationController: _iconCtrl,
              bottomReservedHeight:
                  context.bottomSafePadding +
                  AppSizes.onboardingBottomPadding(context) +
                  96,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  0,
                  ThemeConstants.paddingS,
                  ThemeConstants.paddingL,
                  0,
                ),
                child: OnboardingSkipButton(onTap: _skip),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: OnboardingBottomContent(
              page: _current.toDouble(),
              pageCount: _pages.length,
              isLast: _current == _pages.length - 1,
              onNext: _next,
            ),
          ),
        ],
      ),
    );
  }
}
