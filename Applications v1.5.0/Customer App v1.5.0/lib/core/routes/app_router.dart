import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/cubit/cart_fetch_cubit.dart';
import 'package:customer/features/cart/cubit/cart_recommendations_cubit.dart';
import 'package:customer/features/cart/cubit/guest_cart_fetch_cubit.dart';
import 'package:customer/features/checkout/cubit/place_order_cubit.dart';
import 'package:customer/features/checkout/screens/checkout_screen.dart';
import 'package:customer/features/checkout/screens/order_success_screen.dart';
import 'package:customer/features/chat/screens/chat_screen.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/screens/product_detail_pager.dart';
import 'package:customer/features/products/screens/product_all_reviews_screen.dart';
import 'package:customer/features/products/screens/full_screen_image_viewer.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/promo_code/cubit/promo_code_cubit.dart';
import 'package:customer/features/promo_code/cubit/promo_code_validate_cubit.dart';
import 'package:customer/features/promo_code/screens/promo_code_screen.dart';
import 'package:customer/features/orders/cubit/ecommerce_order_detail_cubit.dart';
import 'package:customer/features/orders/cubit/order_detail_cubit.dart';
import 'package:customer/features/orders/screens/ecommerce_order_detail_screen.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:customer/features/payment_method/cubit/payment_methods_cubit.dart';
import 'package:customer/features/payment_method/screens/payment_methods_screen.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/screens/order_detail_screen.dart';
import 'package:customer/features/orders/screens/order_tracking_screen.dart';
import 'package:customer/features/orders/screens/orders_screen.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/core/routes/category_redirect_args.dart';
import 'package:customer/features/category/cubit/category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_cubit.dart';
import 'package:customer/features/category/cubit/sub_category_selection_cubit.dart';
import 'package:customer/features/category/models/category_model.dart';
import 'package:customer/features/category/screens/category_screen.dart';
import 'package:customer/features/category/screens/sub_category_screen.dart';
import 'package:customer/features/products/cubit/filter_cubit.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/address/cubit/delete_address_cubit.dart';
import 'package:customer/features/address/screens/address_screen.dart';
import 'package:customer/features/profile/screens/refer_earn_screen.dart';
import 'package:customer/features/profile/screens/account_settings_screen.dart';
import 'package:customer/features/auth/cubits/sign_in_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_verify_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/sign_up_cubit.dart';
import 'package:customer/features/auth/cubits/verify_otp_cubit.dart';
import 'package:customer/features/profile/cubit/profile_detail_cubit.dart';
import 'package:customer/features/profile/screens/edit_profile_screen.dart';
import 'package:customer/features/profile/screens/policies_screen.dart';
import 'package:customer/features/notifications/notification/cubit/notifications_cubit.dart';
import 'package:customer/features/notifications/notification_setting/screens/notification_settings_screen.dart';
import 'package:customer/features/notifications/notification/screens/notifications_screen.dart';
import 'package:customer/features/blog/cubit/blog_category_cubit.dart';
import 'package:customer/features/blog/cubit/blog_cubit.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/screens/blog_detail_screen.dart';
import 'package:customer/features/blog/screens/blog_screen.dart';
import 'package:customer/features/faq/cubit/faq_cubit.dart';
import 'package:customer/features/faq/screens/faq_screen.dart';
import 'package:customer/features/spin_wheel/cubit/spin_wheel_config_cubit.dart';
import 'package:customer/features/spin_wheel/cubit/spin_wheel_rewards_cubit.dart';
import 'package:customer/features/spin_wheel/screens/spin_wheel_rewards_screen.dart';
import 'package:customer/features/wallet/cubit/transaction_cubit.dart';
import 'package:customer/features/wallet/cubit/wallet_transaction_cubit.dart';
import 'package:customer/features/wallet/screens/transactions_screen.dart';
import 'package:customer/features/wallet/screens/wallet_transactions_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'route_names.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/register_otp_screen.dart';
import '../../features/main/screens/main_screen.dart';
import '../../features/favourite/screens/favourite_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/location/screens/location_required_screen.dart';
import '../../features/splash/screens/maintenance_screen.dart';
import 'package:customer/commons/widgets/app_text.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return _materialRoute(const SplashScreen());

      case RouteNames.login:
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SignInCubit()),
              BlocProvider(create: (_) => CustomSmsSendPhoneOtpCubit()),
            ],
            child: const SignInScreen(),
          ),
        );

      case RouteNames.register:
        final args = settings.arguments;
        if (args is! RegisterArgs) return _invalidArgsRoute(settings);
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SignUpCubit()),
              BlocProvider(create: (_) => VerifyOtpCubit()),
              BlocProvider(create: (_) => CustomSmsSendPhoneOtpCubit()),
              BlocProvider(create: (_) => CustomSmsVerifyPhoneOtpCubit()),
            ],
            child: SignUpScreen(
              mode: args.mode,
              prefilledEmail: args.email,
              prefilledName: args.name,
              prefilledPhone: args.phone,
              otpVerified: args.otpVerified,
            ),
          ),
        );

      case RouteNames.registerOtp:
        final registerOtpArgsRaw = settings.arguments;
        if (registerOtpArgsRaw is! RegisterOtpArgs) {
          return _invalidArgsRoute(settings);
        }
        final registerOtpArgs = registerOtpArgsRaw;
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SignUpCubit()),
              BlocProvider(create: (_) => VerifyOtpCubit()),
              BlocProvider(create: (_) => CustomSmsSendPhoneOtpCubit()),
              BlocProvider(create: (_) => CustomSmsVerifyPhoneOtpCubit()),
            ],
            child: RegisterOtpScreen(args: registerOtpArgs),
          ),
        );

      case RouteNames.otpVerification:
        final otpArgsRaw = settings.arguments;
        if (otpArgsRaw is! OtpVerificationArgs) {
          return _invalidArgsRoute(settings);
        }
        final otpArgs = otpArgsRaw;
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SignInCubit()),
              BlocProvider(create: (_) => CustomSmsSendPhoneOtpCubit()),
              BlocProvider(create: (_) => CustomSmsVerifyPhoneOtpCubit()),
            ],
            child: OtpVerificationScreen(
              phoneNumber: otpArgs.phone,
              authType: otpArgs.authType,
              countryCode: otpArgs.countryCode,
            ),
          ),
        );

      case RouteNames.onboarding:
        return _materialRoute(const OnboardingScreen());

      case RouteNames.locationRequired:
        return _materialRoute(const LocationRequiredScreen());

      case RouteNames.main:
        return _materialRoute(const MainScreen(), settings: settings);

      case RouteNames.editProfile:
        return _materialRoute(
          BlocProvider(
            create: (context) => ProfileDetailCubit()..loadProfile(),
            child: const EditProfileScreen(),
          ),
        );

      case RouteNames.policies:
        final type =
            settings.arguments as PoliciesType? ?? PoliciesType.privacyPolicy;
        return _materialRoute(PoliciesScreen(type: type));

      case RouteNames.notifications:
        return _materialRoute(const NotificationSettingsScreen());

      case RouteNames.notificationList:
        return _materialRoute(
          BlocProvider(
            create: (_) => NotificationsCubit()..loadNotifications(),
            child: const NotificationsScreen(),
          ),
        );

      case RouteNames.faq:
        return _materialRoute(
          BlocProvider(create: (_) => FaqCubit(), child: const FaqScreen()),
        );

      case RouteNames.spinWheelRewards:
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SpinWheelRewardsCubit()),
              BlocProvider(create: (_) => SpinWheelConfigCubit()),
            ],
            child: const SpinWheelRewardsScreen(),
          ),
        );

      case RouteNames.promoCodes:
        final promoArgs = settings.arguments;
        final String cartTotal;
        String? lat, lng;
        var promoDeliveryType = DeliveryType.delivery;
        if (promoArgs is Map<String, String?>) {
          cartTotal = promoArgs['amount'] ?? '0';
          lat = promoArgs['latitude'];
          lng = promoArgs['longitude'];
          promoDeliveryType = DeliveryType.fromApiValue(
            promoArgs['delivery_type'],
          );
        } else {
          cartTotal = promoArgs as String? ?? '0';
        }
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => PromoCodeCubit()),
              BlocProvider(create: (_) => PromoCodeValidateCubit()),
            ],
            child: PromoCodeScreen(
              cartTotal: cartTotal,
              latitude: lat,
              longitude: lng,
              deliveryType: promoDeliveryType,
            ),
          ),
        );

      case RouteNames.blog:
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => BlogCategoryCubit()),
              BlocProvider(create: (_) => BlogCubit()),
            ],
            child: const BlogScreen(),
          ),
        );

      case RouteNames.blogDetail:
        final blog = settings.arguments;
        if (blog is! Blog) return _invalidArgsRoute(settings);
        return _materialRoute(BlogDetailScreen(blog: blog));

      case RouteNames.transactions:
        return _materialRoute(
          BlocProvider(
            create: (_) => TransactionCubit(),
            child: const TransactionsScreen(),
          ),
        );

      case RouteNames.walletTransactions:
        return _materialRoute(
          BlocProvider(
            create: (_) => WalletTransactionCubit(),
            child: const WalletTransactionsScreen(),
          ),
        );

      case RouteNames.referEarn:
        return _materialRoute(const ReferEarnScreen());

      case RouteNames.addresses:
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => AddressCubit()),
              BlocProvider(create: (_) => DeleteAddressCubit()),
            ],
            child: const AddressScreen(),
          ),
        );

      case RouteNames.categories:
        final rawCategoryArg = settings.arguments;
        String? categoryId;
        var categoryHasChild = true;
        String? categoryName;
        if (rawCategoryArg is CategoryRedirectArgs) {
          categoryId = rawCategoryArg.categoryId;
          categoryHasChild = rawCategoryArg.hasChild;
          categoryName = rawCategoryArg.categoryName;
        } else if (rawCategoryArg is String) {
          categoryId = rawCategoryArg;
        } else if (rawCategoryArg is int) {
          categoryId = rawCategoryArg.toString();
        }
        if (categoryId != null && categoryId.isNotEmpty) {
          final category = Category(id: categoryId, name: categoryName);
          // Same rule as CategoryScreen._onCategoryTap: has_child -> sidebar
          // + subcategory/product panel, no children -> straight to products.
          if (categoryHasChild) {
            return _materialRoute(
              MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) =>
                        SubCategoryCubit(parentCategoryId: categoryId!),
                  ),
                  BlocProvider(create: (_) => SubCategorySelectionCubit()),
                  BlocProvider(create: (_) => SubCategoryChildrenCubit()),
                  BlocProvider(create: (_) => ProductCubit()),
                  BlocProvider(create: (_) => FilterCubit()),
                ],
                child: SubCategoryScreen(parentCategory: category),
              ),
            );
          }
          return _materialRoute(
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      ProductCubit()..loadProducts(categoryId: categoryId!),
                ),
                BlocProvider(
                  create: (_) =>
                      FilterCubit()..loadFilters(categoryId: categoryId!),
                ),
              ],
              child: SubCategoryScreen(
                parentCategory: category,
                showSidebar: false,
              ),
            ),
          );
        }
        return _materialRoute(
          BlocProvider(
            create: (_) => CategoryCubit(),
            child: const CategoryScreen(),
          ),
        );

      case RouteNames.myOrders:
        return _materialRoute(const OrdersScreen());

      case RouteNames.orderDetail:
        final rawArgs = settings.arguments;
        final orderArgs = rawArgs is OrderDetailArgs
            ? rawArgs
            : OrderDetailArgs(orderId: rawArgs as String);
        return _materialRoute(
          BlocProvider(
            create: (_) =>
                OrderDetailCubit()..loadOrderDetail(orderArgs.orderId),
            child: OrderDetailScreen(
              orderId: orderArgs.orderId,
              isOngoing: orderArgs.isOngoing,
              highlightRating: orderArgs.highlightRating,
            ),
          ),
        );

      case RouteNames.ecommerceOrderDetail:
        final rawArgs = settings.arguments;
        final ecommerceOrderArgs = rawArgs is EcommerceOrderDetailArgs
            ? rawArgs
            : EcommerceOrderDetailArgs(orderItemId: rawArgs as String);
        return _materialRoute(
          BlocProvider(
            create: (_) =>
                EcommerceOrderDetailCubit()
                  ..loadOrderDetail(ecommerceOrderArgs.orderItemId),
            child: EcommerceOrderDetailScreen(
              orderItemId: ecommerceOrderArgs.orderItemId,
              isOngoing: ecommerceOrderArgs.isOngoing,
            ),
          ),
        );

      case RouteNames.orderTracking:
        final trackingArgs = settings.arguments;
        if (trackingArgs is OrderData) {
          return _materialRoute(OrderTrackingScreen(order: trackingArgs));
        }
        if (trackingArgs is String) {
          // Called right after checkout with only the id (e.g. order-success
          // screen) — load the order first, then hand it to the tracking screen.
          return _materialRoute(
            BlocProvider(
              create: (_) => OrderDetailCubit()..loadOrderDetail(trackingArgs),
              child: BlocBuilder<OrderDetailCubit, OrderDetailState>(
                builder: (context, state) {
                  if (state is OrderDetailLoaded) {
                    return OrderTrackingScreen(order: state.orderDetail);
                  }
                  if (state is OrderDetailError) {
                    return Scaffold(body: Center(child: Text(state.message)));
                  }
                  return const Scaffold(
                    body: LoadingWidget(),
                  );
                },
              ),
            ),
          );
        }
        return _invalidArgsRoute(settings);

      case RouteNames.paymentMethods:
        final paymentArgs = settings.arguments;
        if (paymentArgs is! PaymentArgs) return _invalidArgsRoute(settings);
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => PaymentMethodsCubit()..loadPaymentMethods(),
              ),
              BlocProvider(create: (_) => PaymentCubit()),
            ],
            child: PaymentMethodsScreen(args: paymentArgs),
          ),
          settings: settings,
        );

      case RouteNames.chat:
        return _materialRoute(const ChatScreen(), settings: settings);

      case RouteNames.accountSettings:
        return _materialRoute(const AccountSettingsScreen());

      case RouteNames.favourite:
        return _materialRoute(const FavouriteScreen());

      case RouteNames.orderSuccess:
        final args = settings.arguments;
        final orderSuccessArgs = args is OrderSuccessArgs
            ? args
            : OrderSuccessArgs(orderId: args as String? ?? '');
        return _materialRoute(
          OrderSuccessScreen(
            orderId: orderSuccessArgs.orderId,
            orderItemId: orderSuccessArgs.orderItemId,
            deliveryType: orderSuccessArgs.deliveryType,
          ),
        );

      case RouteNames.maintenance:
        final remark = settings.arguments as String?;
        return _materialRoute(MaintenanceScreen(remark: remark));

      case RouteNames.checkout:
        return _materialRoute(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => CartFetchCubit()),
              BlocProvider(create: (_) => GuestCartFetchCubit()),
              BlocProvider(create: (_) => CartActionCubit()),
              BlocProvider(create: (_) => AddressCubit()),
              BlocProvider(create: (_) => PaymentMethodsCubit()),
              BlocProvider(create: (_) => PromoCodeValidateCubit()),
              BlocProvider(create: (_) => PlaceOrderCubit()),
              BlocProvider(create: (_) => CartRecommendationsCubit()),
              BlocProvider(create: (_) => PaymentCubit()),
            ],
            child: const CheckoutScreen(),
          ),
        );

      case RouteNames.productDetail:
        final args = settings.arguments;
        final int productId;
        String? imageUrl;
        String heroSuffix = '';
        List<ProductDataModel>? productList;
        int initialIndex = 0;
        if (args is ProductDetailArgs) {
          productId = args.productId;
          imageUrl = args.imageUrl;
          heroSuffix = args.heroSuffix;
          productList = args.productList;
          initialIndex = args.initialIndex;
        } else if (args is int) {
          productId = args;
        } else {
          // Some callers (e.g. notification taps) pass the id as a String.
          productId = int.tryParse(args?.toString() ?? '') ?? 0;
        }
        // Non-opaque: the peek card's own BackdropFilter blurs/dims the
        // previous screen, which only stays painted if this route isn't
        // opaque — a plain MaterialPageRoute drops it and the blur ends up
        // with nothing behind it, reading as flat black instead of a scrim.
        return PageRouteBuilder(
          opaque: false,
          barrierColor: null,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) =>
              ProductDetailPager(
                productId: productId,
                initialImageUrl: imageUrl,
                heroSuffix: heroSuffix,
                productList: productList,
                initialIndex: initialIndex,
              ),
        );

      case RouteNames.productAllReviews:
        final args = settings.arguments;
        if (args is! ProductAllReviewsArgs) return _invalidArgsRoute(settings);
        return _materialRoute(ProductAllReviewsScreen(args: args));

      case RouteNames.fullScreenImageViewer:
        // Product detail passes a 3rd flag: its gallery already decoded
        // these images, so the viewer can show them while it decodes its own.
        final (
          images,
          initialIndex,
          fromProductDetail,
        ) = switch (settings.arguments) {
          (List<String> i, int p, bool d) => (i, p, d),
          (List<String> i, int p) => (i, p, false),
          _ => (<String>[], 0, false),
        };
        return _materialRoute(
          FullScreenImageViewer(
            images: images,
            initialIndex: initialIndex,
            fromProductDetail: fromProductDetail,
          ),
        );

      default:
        // Unmatched route names land here (e.g. a raw deep-link path the OS
        // forwards before DeepLinkService resolves it). Self-replace with
        // MainScreen right after building so this dead-end never stays in
        // the stack underneath a later deep-link push — popping the pushed
        // screen then lands on MainScreen instead of this error screen.
        return _invalidArgsRoute(settings);
    }
  }

  // Shared fallback for both unmatched route names (default case) and routes
  // whose required arguments are missing/wrong-typed (a stray deep link, a
  // caller refactor) — rather than crashing with an uncaught TypeError on an
  // unguarded `as` cast, self-replaces with MainScreen right after building.
  static CupertinoPageRoute _invalidArgsRoute(RouteSettings settings) {
    return _materialRoute(
      AppScaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              AppNavigator.pushReplacementNamed(context, RouteNames.main);
            });
            return Center(
              child: AppText(
                '${context.translate(LanguageLabelKeys.noRouteDefinedFor)} ${settings.name}',
              ),
            );
          },
        ),
      ),
    );
  }

  static CupertinoPageRoute _materialRoute(
    Widget child, {
    RouteSettings? settings,
  }) {
    return CupertinoPageRoute(builder: (_) => child, settings: settings);
  }
}
