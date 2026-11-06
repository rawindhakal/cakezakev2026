import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/localization/cubit/language_cubit.dart';
import 'package:customer/core/localization/cubit/language_select_cubit.dart';
import 'package:customer/core/localization/cubit/localization_cubit.dart';
import 'package:customer/core/localization/locale_resolver.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/api/dio_interceptor.dart';
import 'package:customer/core/theme/cubit/theme_cubit.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/cubit/guest_cart_sync_cubit.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_verify_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/update_fcm_token_cubit.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/features/favourite/cubit/favorite_cubit.dart';
import 'package:customer/features/profile/cubit/profile_detail_cubit.dart';
import 'package:customer/features/profile/cubit/profile_update_cubit.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/commons/cubit/country_settings_cubit.dart';
import 'package:customer/features/home/services/maintenance_socket_service.dart';
import 'package:customer/features/orders/cubit/completed_ecommerce_order_cubit.dart';
import 'package:customer/features/orders/cubit/completed_order_cubit.dart';
import 'package:customer/features/orders/cubit/ongoing_ecommerce_order_cubit.dart';
import 'package:customer/features/orders/cubit/ongoing_order_cubit.dart';
import 'package:customer/commons/widgets/maintenance_scheduled_dialog.dart';
import 'package:customer/firebase_options.dart';
import 'dart:ui';
import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'commons/cubit/connectivity_cubit.dart';
import 'commons/cubit/location_cubit.dart';
import 'core/constants/navigation_service.dart';
import 'core/local_storage/hive_service.dart';
import 'core/routes/app_router.dart';
import 'core/routes/route_names.dart';
import 'core/theme/app_theme.dart';
import 'core/services/analytics_service.dart';
import 'core/services/clarity_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/crashlytics_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final connectivityService = ConnectivityService();

  await Future.wait([
    if (Firebase.apps.isEmpty)
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
    else
      Future.value(Firebase.app()),
    HiveService.init(),
    connectivityService.initialize(),
    LocalizationService.instance.loadFromAssets(),
  ]);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashlyticsService.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Facebook App Events: the native SDK auto-logs standard events (app
  // activate, install) using the App ID / Client Token configured in
  // strings.xml + AndroidManifest.xml (Android) and Info.plist (iOS).
  // Registering the instance here makes it available app-wide for custom
  // event logging via GetIt.instance<FacebookAppEvents>().logEvent(...).
  GetIt.instance.registerSingleton<FacebookAppEvents>(FacebookAppEvents());

  await NotificationService.instance.initialize();

  await DeepLinkService.instance.init(
    NotificationService.instance.navigatorKey,
  );

  // App-wide (not tied to any one screen's lifecycle) so a full-block
  // maintenance toggle takes effect immediately regardless of which screen
  // is on top. Tracks whether *we* pushed the maintenance screen so an
  // "off" toggle only pops it when it's actually the one showing.
  var maintenanceScreenOpen = false;
  MaintenanceSocketService.instance.connect();
  MaintenanceSocketService.instance.onToggled.listen((settings) {
    final navState = NotificationService.instance.navigatorKey.currentState;
    if (navState == null) return;
    final isOn = settings.appModeCustomer == '1';
    if (isOn && !maintenanceScreenOpen) {
      maintenanceScreenOpen = true;
      navState.pushNamed(
        RouteNames.maintenance,
        arguments: settings.appModeCustomerRemark,
      );
    } else if (!isOn && maintenanceScreenOpen) {
      maintenanceScreenOpen = false;
      navState.pop();
    }
  });

  runApp(
    ClarityWidget(app: const MyApp(), clarityConfig: ClarityService.config),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set up 401 unauthorized callback
    DioInterceptor.setOnUnauthorizedCallback(() {
      // Navigate to login when unauthorized
      final navigatorKey = NotificationService.instance.navigatorKey;
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          RouteNames.login,
          (route) => false,
        );
      }
    });

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = CartCubit();
            if (!AuthHiveBox.instance.isLoggedIn) cubit.loadGuestCartFromHive();
            return cubit;
          },
        ),
        BlocProvider(create: (_) => CartActionCubit()),
        BlocProvider(create: (_) => GuestCartSyncCubit()),
        BlocProvider(create: (_) => AuthCubit()..checkAuth()),
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => ConnectivityCubit()),
        BlocProvider(create: (_) => LocationCubit()),
        BlocProvider(create: (_) => SettingsCubit()),
        BlocProvider(create: (_) => CountrySettingsCubit()),
        BlocProvider(create: (_) => CountriesCubit()..fetchCountries()),
        BlocProvider(create: (_) => FavoriteCubit()),
        BlocProvider(
          create: (_) {
            final cubit = ProfileDetailCubit();
            if (AuthHiveBox.instance.isLoggedIn) cubit.loadProfile();
            return cubit;
          },
        ),
        BlocProvider(create: (_) => ProfileUpdateCubit()),
        BlocProvider(create: (_) => LanguageCubit()..loadLanguages()),
        BlocProvider(create: (_) => LanguageSelectCubit()),
        BlocProvider(create: (_) => LocalizationCubit()),
        BlocProvider(create: (_) => UpdateFcmTokenCubit()),
        BlocProvider(create: (_) => CustomSmsSendPhoneOtpCubit()),
        BlocProvider(create: (_) => CustomSmsVerifyPhoneOtpCubit()),
        // App-wide (not screen-scoped) so an "order" push can refetch the
        // listing even when OrdersScreen isn't open — see
        // NotificationService._refreshOrderLists.
        BlocProvider(create: (_) => OngoingOrderCubit()),
        BlocProvider(create: (_) => CompletedOrderCubit()),
        BlocProvider(create: (_) => OngoingEcommerceOrderCubit()),
        BlocProvider(create: (_) => CompletedEcommerceOrderCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return BlocBuilder<LanguageCubit, LanguageState>(
            buildWhen: (prev, next) {
              if (prev is LanguageLoaded && next is LanguageLoaded) {
                return prev.selectedId != next.selectedId;
              }
              return next is LanguageLoaded;
            },
            builder: (context, langState) {
              final (direction, locale) = resolveLocale(langState);
              return BlocConsumer<SettingsCubit, SettingsState>(
                buildWhen: (prev, next) => next is SettingsLoaded,
                listenWhen: (prev, next) => next is SettingsLoaded,
                listener: (context, settingsState) {
                  if (settingsState is SettingsLoaded) {
                    ClarityService.applyStatus(
                      settingsState.settings.data?.clarityStatusCustomer,
                    );
                    // Retried on every settings load (idempotent — connect()
                    // no-ops once already connected) because the connect()
                    // call at app boot runs before settings are fetched, so
                    // the cold-start broadcast_driver/config may still be
                    // empty/stale at that point.
                    MaintenanceSocketService.instance.connect();
                    // Wait until the splash screen has navigated away —
                    // showDialog pushes onto the same root navigator splash
                    // uses for its own pushReplacementNamed, and that call
                    // replaces whatever is currently on top of the stack. If
                    // the dialog is up when it fires, pushReplacementNamed
                    // wipes the dialog out instead of splash.
                    AppNavigator.readyFuture.then((_) {
                      final ctx = NotificationService
                          .instance
                          .navigatorKey
                          .currentContext;
                      if (ctx != null && ctx.mounted) {
                        MaintenanceScheduledDialog.maybeShow(ctx);
                      }
                    });
                  }
                },
                builder: (context, settingsState) {
                  final settingsCubit = context.read<SettingsCubit>();
                  return MaterialApp(
                    title: AppConfig.appName,
                    debugShowCheckedModeBanner: false,
                    navigatorKey: NotificationService.instance.navigatorKey,
                    navigatorObservers: [
                      AnalyticsService.instance.navigatorObserver,
                    ],
                    theme: AppTheme.lightTheme(
                      settingsCubit.getLightPrimaryColor(),
                    ),
                    darkTheme: AppTheme.darkTheme(
                      settingsCubit.getDarkPrimaryColor(),
                    ),
                    themeMode: themeState.themeMode,
                    // Disabled: MaterialApp's own theme cross-fade otherwise
                    // plays underneath our circular-reveal overlay, washing
                    // out its colors while both animate at once. Our reveal
                    // is the only theme transition that should be visible.
                    themeAnimationDuration: Duration.zero,
                    locale: locale,
                    supportedLocales: [locale],
                    localeResolutionCallback: (_, _) => locale,
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    initialRoute: RouteNames.splash,
                    onGenerateRoute: AppRouter.generateRoute,
                    builder: (_, child) => LocalizationScope(
                      notifier: LocalizationService.instance,
                      child: Directionality(
                        textDirection: direction,
                        child: child!,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
