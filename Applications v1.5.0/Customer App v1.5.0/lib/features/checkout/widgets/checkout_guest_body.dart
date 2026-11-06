import 'package:customer/commons/widgets/saved_amount_banner.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/cart/cubit/guest_cart_fetch_cubit.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/checkout/utils/checkout_totals.dart';
import 'package:customer/features/checkout/widgets/checkout_bill_section.dart';
import 'package:customer/features/checkout/widgets/checkout_cart_items_section.dart';
import 'package:customer/features/checkout/widgets/checkout_place_order_bar.dart';
import 'package:customer/features/checkout/widgets/checkout_recommendations_section.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The logged-out checkout body — read-only cart + bill preview, ending in a
/// "log in to checkout" prompt instead of the real place-order flow.
class CheckoutGuestBody extends StatelessWidget {
  const CheckoutGuestBody({
    super.key,
    required this.cartData,
    required this.currency,
    required this.onLoginAndCheckout,
    this.scrollController,
    this.deliveryType = DeliveryType.delivery,
    this.onAddMoreItems,
  });

  final CartData cartData;
  final String currency;
  final VoidCallback onLoginAndCheckout;

  /// "Forgot something? Add More Items" tap handler.
  final VoidCallback? onAddMoreItems;

  /// Carried into the pull-to-refresh's fetchGuestCart so refreshing doesn't
  /// silently drop back to 'delivery' mid pickup selection.
  final DeliveryType deliveryType;

  // Drives the app bar's scroll-shadow.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final saved = resolveCheckoutSavedAmount(cartData: cartData);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: context.cs.primary,
            onRefresh: () {
              // Add-on module: request carries add-on lines' answers too.
              final req = context.read<CartCubit>().state.guestCartRequest;
              return context.read<GuestCartFetchCubit>().fetchGuestCart(
                variantIds: req.variantIds,
                quantities: req.quantities,
                items: req.items,
                deliveryType: deliveryType,
              );
            },
            child: ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(
                ThemeConstants.paddingL,
                ThemeConstants.paddingM,
                ThemeConstants.paddingL,
                0,
              ),
              children: [
                if (saved > 0) ...[
                  SavedAmountBanner(
                    amountText:
                        '$currency${saved.formatPrice(cartData.decimalPoint ?? 2)}',
                    style: SavedAmountBannerStyle.rounded,
                  ),
                  AppSpacing.h12,
                ],
                CheckoutCartItemsSection(
                  cartData: cartData,
                  currency: currency,
                  onAddMoreItems: onAddMoreItems,
                ),
                AppSpacing.h12,
                const CheckoutRecommendationsSection(),
                CheckoutBillDetailsSection(
                  cartData: cartData,
                  currency: currency,
                  appliedPromo: null,
                  isPickup: deliveryType == DeliveryType.pickup,
                ),
                AppSpacing.h100,
              ],
            ),
          ),
        ),
        CheckoutPlaceOrderBar(
          cartData: cartData,
          currency: currency,
          isLoading: false,
          isLoggedIn: false,
          selectedAddress: null,
          selectedPayment: null,
          onPlaceOrder: () {},
          onChooseAddress: () {},
          onChoosePayment: () {},
          billingSameAsShipping: true,
          billingAddress: null,
          onBillingToggle: (_) {},
          onEditBillingAddress: () {},
          onLoginAndCheckout: onLoginAndCheckout,
        ),
      ],
    );
  }
}
