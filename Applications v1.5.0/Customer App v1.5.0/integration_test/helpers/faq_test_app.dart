import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/core/routes/app_router.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_theme.dart';

/// Minimal real-router harness for the FAQ feature: `RouteNames.faq`'s own
/// route already wires its own `BlocProvider<FaqCubit>` (see
/// `AppRouter.generateRoute`), so nothing feature-specific needs providing
/// here — only `ConnectivityCubit`, which `FaqScreen` reads directly via
/// `context.read`. No auth/Firebase/Hive setup: FAQ needs none of them,
/// unlike delivery-boy's `auth_test_app.dart`-style harnesses.
///
/// `MaterialApp.initialRoute`'s default `onGenerateInitialRoutes` always
/// builds `RouteNames.splash` first and stacks the requested route on top of
/// it (Navigator's `defaultGenerateInitialRoutes` unconditionally seeds the
/// history with the app's default route before the requested one) —
/// `SplashScreen` needs `SettingsCubit`/`LanguageCubit`/`LocalizationCubit`,
/// none of which this harness provides. `onGenerateInitialRoutes` is
/// overridden here to build only the one route this test actually needs.
class FaqTestApp extends StatelessWidget {
  const FaqTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConnectivityCubit(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(AppColors.primary),
        onGenerateInitialRoutes: (initialRouteName) => [
          AppRouter.generateRoute(const RouteSettings(name: RouteNames.faq)),
        ],
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
