import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/features/auth/cubit/sign_in_cubit.dart';
import 'package:deliveryboy/features/chat/screens/chat_screen.dart';
import 'package:deliveryboy/features/orders/cubit/order_live_tracking_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/road_route_cubit.dart';
import 'package:deliveryboy/features/orders/screens/order_tracking_screen.dart';
import 'package:deliveryboy/features/orders/cubit/scan_delivery_receipt_cubit.dart';
import 'package:deliveryboy/features/orders/screens/order_scanner_screen.dart';
import 'package:deliveryboy/features/cash_collection/cubit/cash_collection_cubit.dart';
import 'package:deliveryboy/features/cash_collection/screens/cash_collection_screen.dart';
import 'package:deliveryboy/features/settlement_history/cubit/settlement_history_cubit.dart';
import 'package:deliveryboy/features/settlement_history/screens/settlement_history_screen.dart';
import 'package:deliveryboy/features/orders/screens/order_detail_screen.dart';
import 'package:deliveryboy/features/orders/screens/ecommerce_order_detail_screen.dart';
import 'package:deliveryboy/features/orders/screens/return_order_detail_screen.dart';
import 'package:deliveryboy/features/profile/screens/account_settings_screen.dart';
import 'package:deliveryboy/features/profile/screens/edit_profile_screen.dart';
import 'package:deliveryboy/features/salary/cubit/salary_cubit.dart';
import 'package:deliveryboy/features/salary/screens/salary_screen.dart';
import 'package:deliveryboy/features/earnings/screens/earnings_screen.dart';
import 'package:deliveryboy/features/profile/screens/policies_screen.dart';
import 'package:deliveryboy/features/notifications/screens/notification_screen.dart';
import 'package:deliveryboy/features/wallet/cubit/wallet_cubit.dart';
import 'package:deliveryboy/features/wallet/screens/wallet_screen.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'route_names.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/main/screens/main_screen.dart';
import '../../features/splash/screens/maintenance_screen.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Maps [RouteNames] to their screens for [MaterialApp.onGenerateRoute].
class AppRouter {
  AppRouter._();

  /// Builds the [Route] for the given [settings.name], wiring up any required cubits/args.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return _materialRoute(const SplashScreen());

      case RouteNames.login:
        return _materialRoute(
          BlocProvider(
            create: (context) => SignInCubit(),
            child: const SignInScreen(),
          ),
        );

      case RouteNames.register:
        return _materialRoute(const SignUpScreen());

      case RouteNames.main:
        return _materialRoute(const MainScreen());

      case RouteNames.cashCollection:
        return _materialRoute(
          BlocProvider(
            create: (context) => CashCollectionCubit(),
            child: const CashCollectionScreen(),
          ),
        );

      case RouteNames.settlementHistory:
        return _materialRoute(
          BlocProvider(
            create: (context) => SettlementHistoryCubit(),
            child: const SettlementHistoryScreen(),
          ),
        );

      case RouteNames.salary:
        return _materialRoute(
          BlocProvider(
            create: (context) => SalaryCubit(),
            child: const SalaryScreen(),
          ),
        );

      case RouteNames.earnings:
        return _materialRoute(const EarningsScreen());

      case RouteNames.orderDetail:
        return _materialRoute(const OrderDetailScreen(), settings: settings);

      case RouteNames.ecommerceOrderDetail:
        return _materialRoute(
          const EcommerceOrderDetailScreen(),
          settings: settings,
        );

      case RouteNames.returnOrderDetail:
        return _materialRoute(
          const ReturnOrderDetailScreen(),
          settings: settings,
        );

      case RouteNames.editProfile:
        return _materialRoute(const EditProfileScreen());

      case RouteNames.policies:
        final type =
            settings.arguments as PoliciesType? ?? PoliciesType.privacyPolicy;
        return _materialRoute(PoliciesScreen(type: type));

      case RouteNames.orderTracking:
        final args = settings.arguments as OrderTrackingArgs;
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => OrderLiveTrackingCubit()),
              BlocProvider(create: (context) => RoadRouteCubit()),
            ],
            child: OrderTrackingScreen(args: args),
          ),
        );

      case RouteNames.orderScanner:
        return _materialRoute(
          BlocProvider(
            create: (context) => ScanDeliveryReceiptCubit(),
            child: const OrderScannerScreen(),
          ),
        );

      case RouteNames.notifications:
        return _materialRoute(const NotificationScreen());

      case RouteNames.wallet:
        return _materialRoute(
          BlocProvider(
            create: (context) => WalletCubit(),
            child: const WalletScreen(),
          ),
        );

      case RouteNames.chat:
        return _materialRoute(const ChatScreen(), settings: settings);

      case RouteNames.accountSettings:
        return _materialRoute(const AccountSettingsScreen());

      case RouteNames.maintenance:
        final remark = settings.arguments as String?;
        // settings passed through so the route carries its name — main.dart
        // dismisses this screen by name when the maintenance socket toggles off.
        return _materialRoute(
          MaintenanceScreen(remark: remark),
          settings: settings,
        );

      default:
        return _materialRoute(
          AppScaffold(
            body: Center(
              child: AppText(
                '${LocalizationService.instance.translate(LanguageLabelKeys.noRouteDefined)} ${settings.name}',
              ),
            ),
          ),
        );
    }
  }

  static CupertinoPageRoute _materialRoute(Widget child, {RouteSettings? settings}) {
    return CupertinoPageRoute(builder: (_) => child, settings: settings);
  }
}
