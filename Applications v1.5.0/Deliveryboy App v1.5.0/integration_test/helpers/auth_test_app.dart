import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/cubit/language_select_cubit.dart';
import 'package:deliveryboy/core/localization/cubit/localization_cubit.dart';
import 'package:deliveryboy/core/routes/app_router.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/core/theme/cubit/theme_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/add_fcm_token_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/auth_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/update_fcm_token_cubit.dart';
import 'package:deliveryboy/features/home/cubit/dashboard_cubit.dart';
import 'package:deliveryboy/features/home/cubit/delivery_boy_status_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:deliveryboy/features/profile/cubit/profile_update_cubit.dart';

/// Marker for the screen that stands in for the post-login destination.
/// `find.byType(PostLoginPlaceholder)` is how a test asserts "login finished
/// and navigated on".
class PostLoginPlaceholder extends StatelessWidget {
  const PostLoginPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('logged in')));
}

/// The real auth navigation stack — real router, real screens, real cubits —
/// wired to whatever the FakeApiAdapter serves.
///
/// The provider list mirrors `lib/main.dart`'s `MultiBlocProvider` so the auth
/// screens resolve every dependency they really read. Unlike main.dart,
/// nothing is kicked off in `create` (no `..checkAuth()`, `..loadProfile()`,
/// `..fetchCountries()`) — the tests drive the flows they care about, and any
/// endpoint a screen does call is answered by the fake adapter rather than the
/// network.
///
/// `RouteNames.main` resolves to [PostLoginPlaceholder] instead of the real
/// `MainScreen`: everything past login (dashboard, orders, earnings, profile,
/// their sockets and location work) belongs to those features' own
/// integration tests, and mounting it here made auth flows fail on unrelated
/// home-feature errors. Every other route still goes through the real
/// `AppRouter`. Pass [mainScreenBuilder] to put something else there — e.g. a
/// host that opens the logout/delete dialogs the profile tab normally owns.
class AuthTestApp extends StatelessWidget {
  final String initialRoute;
  final WidgetBuilder? mainScreenBuilder;

  /// Route arguments for [initialRoute]. `MaterialApp.initialRoute` generates
  /// its route with no arguments, so a screen that reads
  /// `ModalRoute.of(context)!.settings.arguments` (e.g. `ChatScreen`'s
  /// `ChatScreenArgs`) would otherwise crash when mounted as the first route.
  final Object? initialRouteArguments;

  const AuthTestApp({
    super.key,
    required this.initialRoute,
    this.mainScreenBuilder,
    this.initialRouteArguments,
  });

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    if (settings.name == initialRoute &&
        settings.arguments == null &&
        initialRouteArguments != null) {
      settings = RouteSettings(
        name: settings.name,
        arguments: initialRouteArguments,
      );
    }
    if (settings.name == RouteNames.main) {
      return MaterialPageRoute(
        builder:
            mainScreenBuilder ?? (_) => const PostLoginPlaceholder(),
        settings: settings,
      );
    }
    return AppRouter.generateRoute(settings);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => ConnectivityCubit()),
        BlocProvider(create: (_) => DashboardCubit()),
        BlocProvider(create: (_) => OrderCubit()),
        BlocProvider(create: (_) => EcommerceOrderCubit()),
        BlocProvider(create: (_) => ReturnOrderCubit()),
        BlocProvider(create: (_) => SettingsCubit()),
        BlocProvider(create: (_) => DeliveryBoyStatusCubit()),
        BlocProvider(create: (_) => ProfileDetailCubit()),
        BlocProvider(create: (_) => CountriesCubit()),
        BlocProvider(create: (_) => CountrySettingsCubit()),
        BlocProvider(create: (_) => ProfileUpdateCubit()),
        BlocProvider(create: (_) => LanguageCubit()),
        BlocProvider(create: (_) => LanguageSelectCubit()),
        BlocProvider(create: (_) => LocalizationCubit()),
        BlocProvider(create: (_) => OrderStatusListFilterCubit()),
        BlocProvider(create: (_) => ReturnOrderStatusListFilterCubit()),
        BlocProvider(create: (_) => UpdateFcmTokenCubit()),
        BlocProvider(create: (_) => AddFcmTokenCubit()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        initialRoute: initialRoute,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }
}
