import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  /// Screens that position their own flush-to-bottom overlays (e.g. a
  /// floating bar meant to sit against/over the bottom nav) should pass
  /// false — otherwise this scaffold's own bottom padding pushes that
  /// overlay up, leaving a gap between it and the nav bar.
  final bool applyBottomInset;

  /// Whether the body draws full-height behind [bottomNavigationBar] (the
  /// default — needed for the floating-overlay bottom nav look). Screens
  /// with a variable-height bottom bar (e.g. an action button that may or
  /// may not render) should pass false together with `applyBottomInset:
  /// false` — Scaffold then sizes the body to stop exactly above the bar
  /// on its own, instead of this widget guessing a fixed reserved height.
  final bool extendBody;

  const AppScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
    this.backgroundColor,
    this.applyBottomInset = true,
    this.extendBody = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final keyboardOpen = media.viewInsets.bottom > 0;
    final bottomSafe = media.padding.bottom;
    final hasBottomNav = bottomNavigationBar != null;

    final double bottomPadding = !applyBottomInset || keyboardOpen
        ? 0
        : hasBottomNav
        ? kBottomNavigationBarHeight + ThemeConstants.paddingL + bottomSafe
        : bottomSafe;

    final theme = Theme.of(context);
    final scaffoldColor = backgroundColor ?? theme.scaffoldBackgroundColor;
    // The system nav bar strip sits directly behind whichever widget is at
    // the very bottom — the app's own bottom nav bar when present (it draws
    // its own surface color), otherwise the scaffold background.
    final systemNavBarColor = hasBottomNav
        ? theme.colorScheme.surface
        : scaffoldColor;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            systemNavigationBarColor: systemNavBarColor,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
      child: Scaffold(
        extendBody: extendBody,
        resizeToAvoidBottomInset: true,
        appBar: appBar,
        backgroundColor: scaffoldColor,
        body: Padding(
          padding: EdgeInsetsDirectional.only(bottom: bottomPadding),
          child: body,
        ),
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
