import 'package:customer/core/constants/assets_constants.dart';
import 'package:lottie/lottie.dart';

import '../../../commons/widgets/app_text.dart';

import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    this.orderItemId = '',
    this.deliveryType = DeliveryType.delivery,
  });

  final String orderId;

  /// Ecommerce channel's item-level id — used to route "Track My Order"
  /// to the ecommerce order-detail screen instead of orderId.
  final String orderItemId;

  /// Quick-channel "Track My Order" routes to order-tracking for delivery,
  /// order-detail for pickup (no live rider to track).
  final DeliveryType deliveryType;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  // Content stagger
  late final AnimationController _contentCtrl;
  late final Animation<double> _titleAnim;
  late final Animation<double> _subtitleAnim;
  late final Animation<double> _btnAnim;

  @override
  void initState() {
    super.initState();

    // Order placed — clear cart both server-side and locally so the
    // floating cart bar/badge don't linger with stale items.
    if (AuthHiveBox.instance.isLoggedIn) {
      context.read<CartActionCubit>().clearCart();
    }
    context.read<CartCubit>().clear();

    // ── Content stagger (900ms) ────────────────────────────────────────────
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _titleAnim = CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    );
    _subtitleAnim = CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
    );
    _btnAnim = CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );

    // ── Start chain ────────────────────────────────────────────────────────
    AppHaptics.success();
    _contentCtrl.forward();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AppScaffold(
        applyBottomInset: false,
        bottomNavigationBar: _SlideIn(
          animation: _btnAnim,
          offset: const Offset(0, 0.25),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingL,
              ThemeConstants.paddingM,
              ThemeConstants.paddingL,
              ThemeConstants.paddingM + context.bottomSafePadding,
            ),
            child: Column(
              mainAxisSize: .min,
              children: [
                if (widget.orderId.isNotEmpty)
                  AppButton(
                    label: context.translate(LanguageLabelKeys.trackMyOrder),
                    onPressed: () {
                      final isEcommerce =
                          SettingsHiveBox.instance.channel ==
                          AppConstants.ecommerce;
                      if (isEcommerce) {
                        AppNavigator.pushReplacementNamed(
                          context,
                          RouteNames.ecommerceOrderDetail,
                          arguments: EcommerceOrderDetailArgs(
                            orderItemId: widget.orderItemId.isNotEmpty
                                ? widget.orderItemId
                                : widget.orderId,
                            isOngoing: true,
                          ),
                        );
                      } else if (widget.deliveryType == DeliveryType.pickup) {
                        // No live rider for a pickup order — land on the
                        // order-detail screen (pickup store, status) instead
                        // of the delivery-tracking map.
                        AppNavigator.pushReplacementNamed(
                          context,
                          RouteNames.orderDetail,
                          arguments: OrderDetailArgs(
                            orderId: widget.orderId,
                            isOngoing: true,
                          ),
                        );
                      } else {
                        AppNavigator.pushReplacementNamed(
                          context,
                          RouteNames.orderTracking,
                          arguments: widget.orderId,
                        );
                      }
                    },
                  ),
                AppSpacing.h12,
                AppButton(
                  label: context.translate(LanguageLabelKeys.continueShopping),
                  variant: AppButtonVariant.outline,
                  onPressed: () => AppNavigator.pushNamedAndRemoveUntil(
                    context,
                    RouteNames.main,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingL,
          ),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              // ── Animated checkmark ──────────────────────────────────
              Lottie.asset(AssetsConstants.successCircleCheck, repeat: true),

              // ── Title ──────────────────────────────────────────────
              _SlideIn(
                animation: _titleAnim,
                child: AppText(
                  context.translate(LanguageLabelKeys.orderPlaced),
                  style: context.tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                  textAlign: .center,
                ),
              ),
              AppSpacing.h10,

              // ── Subtitle ───────────────────────────────────────────
              _SlideIn(
                animation: _subtitleAnim,
                offset: const Offset(0, 0.35),
                child: AppText(
                  context.translate(
                    LanguageLabelKeys.orderConfirmedBeingPrepared,
                  ),
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurface.withValues(alpha: 0.58),
                    height: 1.6,
                  ),
                  textAlign: .center,
                ),
              ),
              AppSpacing.h24,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SlideIn extends StatelessWidget {
  const _SlideIn({
    required this.animation,
    required this.child,
    this.offset = const Offset(0, 0.4),
  });

  final Animation<double> animation;
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: FractionalTranslation(
          translation: Offset(
            offset.dx * (1 - animation.value),
            offset.dy * (1 - animation.value),
          ),
          child: child,
        ),
      ),
    );
  }
}
