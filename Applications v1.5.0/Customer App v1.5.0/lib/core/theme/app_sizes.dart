import 'package:flutter/material.dart';

class AppSizes {
  AppSizes._();

  // ── Breakpoints ───────────────────────────────────────────────────────────

  static const double tabletBreakpoint = 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= tabletBreakpoint;

  /// Device-type check without BuildContext, for use outside the widget tree (e.g. repositories).
  static bool get isTabletDevice {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
    return shortestSide >= tabletBreakpoint;
  }

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// 0 at phone width (360) up to 1 at tablet breakpoint (600+) — used to
  /// scale onboarding sizes off a single widget tree instead of branching
  /// on a separate tablet layout.
  static double _onboardingScale(BuildContext context) =>
      ((MediaQuery.of(context).size.shortestSide - 360) /
              (tabletBreakpoint - 360))
          .clamp(0.0, 1.0);

  static double _lerpOnboarding(
    BuildContext context,
    double mobile,
    double tablet,
  ) => mobile + (tablet - mobile) * _onboardingScale(context);

  // ── Onboarding – illustration ─────────────────────────────────────────────

  static double onboardingOuterSize(BuildContext context) =>
      _lerpOnboarding(context, 160, 200);
  static double onboardingInnerSize(BuildContext context) =>
      _lerpOnboarding(context, 120, 150);
  static double onboardingIconSize(BuildContext context) =>
      _lerpOnboarding(context, 58, 72);
  static double onboardingBottomPadding(BuildContext context) =>
      _lerpOnboarding(context, 60, 80);

  // ── Onboarding – bottom card ──────────────────────────────────────────────

  static double onboardingCardPaddingH(BuildContext context) =>
      _lerpOnboarding(context, 28, 48);
  static double onboardingCardPaddingV(BuildContext context) =>
      _lerpOnboarding(context, 32, 40);

  // ── Onboarding – next button ──────────────────────────────────────────────

  static double onboardingButtonSize(BuildContext context) =>
      _lerpOnboarding(context, 56, 64);
  static double onboardingFontSize(BuildContext context) =>
      _lerpOnboarding(context, 15, 17);

  // ── Onboarding – title/subtitle ───────────────────────────────────────────

  static double onboardingTitleFontSize(BuildContext context) =>
      _lerpOnboarding(context, 24, 30);
  static double onboardingSubtitleFontSize(BuildContext context) =>
      _lerpOnboarding(context, 14, 16);

  // ── Onboarding – gradient background height ratio ─────────────────────────

  static const double onboardingBgHeightRatio = 0.58;

  // ── Onboarding – landscape split ratio ───────────────────────────────────

  static const double onboardingLandscapeIllustrationFlex = 1;
  static const double onboardingLandscapeContentFlex = 1;
}
