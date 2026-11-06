import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_theme.dart';

/// Wraps [child] in the same light `ThemeData` the real app builds in
/// `lib/main.dart`, so widgets reading `context.cs` / `context.tt` resolve
/// the same roles they do in the app instead of falling back to defaults.
/// Unlike deliveryboy, this app's primary color is server-configurable
/// (`SettingsCubit.getLightPrimaryColor()`) — tests use `AppColors.primary`,
/// the same placeholder the real app falls back to before that loads.
///
/// Pass `wrapInScaffold: false` for a widget that builds its own Scaffold
/// (e.g. a full screen using `AppScaffold`) — nesting one Scaffold inside
/// another leaves two in the tree and breaks `find.byType(Scaffold)`.
Widget pumpTestWidget(Widget child, {bool wrapInScaffold = true}) {
  // AppTheme's text theme comes from google_fonts, which falls back to
  // downloading a font file at runtime when it isn't bundled. Under
  // `flutter test` that request never resolves, and any test that lets real
  // time pass (a `runAsync` block, say) hangs the runner on it instead of
  // failing. Fonts render with the default typeface here, which no assertion
  // depends on.
  GoogleFonts.config.allowRuntimeFetching = false;

  return MaterialApp(
    theme: AppTheme.lightTheme(AppColors.primary),
    home: wrapInScaffold ? Scaffold(body: child) : child,
  );
}
