import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/core/routes/app_router.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_theme.dart';

/// Real-router harness for the auth feature, mounted directly at
/// `RouteNames.login`. Unlike faq/blog's single-cubit screens, `SignInScreen`
/// itself reads three cubits it does *not* get from its own route:
/// `SettingsCubit` (its `BlocBuilder` gates the whole screen behind
/// `SettingsLoaded`) and `CountriesCubit` (read directly in
/// `_initModeIfNeeded`, plus a `BlocListener`) are both provided **globally**
/// in `main.dart`'s app-level `MultiBlocProvider`, not per-route the way
/// `AppRouter.generateRoute`'s `/login` case wires `SignInCubit`/
/// `CustomSmsSendPhoneOtpCubit` — so this harness has to supply them itself,
/// unlike faq/blog's harnesses which needed nothing beyond
/// `ConnectivityCubit`. This is the "broader provider wiring" TESTING.md's
/// setup section anticipated for the first feature's integration harness.
///
/// A successful login (`SignInLoaded`) hands off to
/// `GuestCartSyncHelper.syncAndNavigate`, which — with an empty
/// `GuestCartHiveBox` (the default for a fresh temp-dir Hive, which is what
/// every test here runs against) — skips the cart-merge branch entirely and
/// navigates straight to `RouteNames.locationRequired` (since a fresh
/// `SettingsHiveBox` has no saved location). That screen builds its own
/// `BlocProvider<UserLocationCubit>` internally, so no further global
/// provider is needed to land there — deliberately not `RouteNames.main`,
/// which would need most of `main.dart`'s entire provider list.
class AuthTestApp extends StatelessWidget {
  const AuthTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ConnectivityCubit()),
        BlocProvider(create: (_) => SettingsCubit()..loadSettings()),
        BlocProvider(create: (_) => CountriesCubit()..fetchCountries()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(AppColors.primary),
        // Same `onGenerateInitialRoutes` override faq/blog's harnesses
        // needed: `Navigator.defaultGenerateInitialRoutes` always seeds the
        // history with `RouteNames.splash` first, which needs
        // `LanguageCubit`/`LocalizationCubit` this harness doesn't provide —
        // build only the `/login` route directly instead.
        onGenerateInitialRoutes: (initialRouteName) => [
          AppRouter.generateRoute(const RouteSettings(name: RouteNames.login)),
        ],
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
