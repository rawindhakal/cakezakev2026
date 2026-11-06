import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppScaffold extends StatefulWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  /// Screens that position their own flush-to-bottom overlays (e.g. a
  /// floating bar meant to sit against/over the bottom nav) should pass
  /// false — otherwise this scaffold's own bottom padding pushes that
  /// overlay up, leaving a gap between it and the nav bar.
  final bool applyBottomInset;

  /// Lets the body draw behind a transparent/translucent app bar (e.g. a
  /// bar that fades out on scroll) instead of stopping below it. The body
  /// is responsible for reserving its own top inset when content shouldn't
  /// start under the status bar/app bar.
  final bool extendBodyBehindAppBar;

  const AppScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
    this.backgroundColor,
    this.applyBottomInset = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final _bottomNavKey = GlobalKey();
  double? _bottomNavHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  // The bar's real height (e.g. AuthTermsBar wraps to multiple lines
  // depending on translation length / font scale) isn't known until it has
  // laid out once, so the body reserves an assumed height for the first
  // frame, then re-measures and corrects itself — avoiding a permanent
  // overlap for bars taller than kBottomNavigationBarHeight.
  void _scheduleMeasure() {
    if (widget.bottomNavigationBar == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _bottomNavKey.currentContext?.size?.height;
      if (height != null && height != _bottomNavHeight) {
        setState(() => _bottomNavHeight = height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final keyboardOpen = media.viewInsets.bottom > 0;
    final bottomSafe = media.padding.bottom;
    final hasBottomNav = widget.bottomNavigationBar != null;
    final navHeight = _bottomNavHeight ?? kBottomNavigationBarHeight;

    // navHeight is the bar's real measured height — bars are expected to
    // reserve their own bottom safe-area inset internally (AuthTermsBar,
    // BottomNavBar, _SaveBar all do), so it isn't added again here.
    final double bottomPadding = !widget.applyBottomInset || keyboardOpen
        ? 0
        : hasBottomNav
        ? navHeight + ThemeConstants.paddingL
        : bottomSafe;

    final theme = Theme.of(context);
    final scaffoldColor =
        widget.backgroundColor ?? theme.scaffoldBackgroundColor;
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
        extendBody: true,
        extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
        resizeToAvoidBottomInset: true,
        appBar: widget.appBar,
        backgroundColor: scaffoldColor,
        body: Padding(
          padding: EdgeInsetsDirectional.only(bottom: bottomPadding),
          child: widget.body,
        ),
        bottomNavigationBar: hasBottomNav
            ? NotificationListener<SizeChangedLayoutNotification>(
                // The bar's own bloc/state content (e.g. a save-bar that's
                // empty until data loads, or a bottom sheet whose content
                // swaps size) can resize without this widget's config ever
                // changing — didUpdateWidget/didChangeDependencies wouldn't
                // fire for that, so the reserved body padding would stay
                // stuck at whatever the bar measured on first frame. This
                // catches every size change the bar itself produces.
                onNotification: (_) {
                  _scheduleMeasure();
                  return false;
                },
                child: SizeChangedLayoutNotifier(
                  key: _bottomNavKey,
                  child: widget.bottomNavigationBar!,
                ),
              )
            : null,
      ),
    );
  }
}
