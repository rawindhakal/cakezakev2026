import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/core/routes/app_router.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_theme.dart';

/// Minimal real-router harness for the blog feature, mirroring
/// `faq_test_app.dart`: `RouteNames.blog`'s own route already wires its own
/// `BlocProvider<BlogCategoryCubit>` + `BlocProvider<BlogCubit>` (see
/// `AppRouter.generateRoute`), so nothing feature-specific needs providing
/// here — only `ConnectivityCubit`, which `BlogScreen` reads directly via
/// `context.read`. `AppRouter.generateRoute` also handles
/// `RouteNames.blogDetail` itself (reading the pushed `Blog` argument), so
/// tapping a card through to the detail screen works with no extra wiring.
///
/// Same `onGenerateInitialRoutes` override faq's harness needed:
/// `MaterialApp.initialRoute`'s default `onGenerateInitialRoutes` always
/// builds `RouteNames.splash` first and stacks the requested route on top of
/// it, and `SplashScreen` needs cubits this harness doesn't provide.
class BlogTestApp extends StatelessWidget {
  const BlogTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConnectivityCubit(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(AppColors.primary),
        onGenerateInitialRoutes: (initialRouteName) => [
          AppRouter.generateRoute(const RouteSettings(name: RouteNames.blog)),
        ],
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
