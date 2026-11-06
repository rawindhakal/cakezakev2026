import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/cart/cubit/cart_fetch_cubit.dart';
import 'package:customer/features/cart/cubit/guest_cart_fetch_cubit.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/checkout/cubit/place_order_cubit.dart';
import 'package:customer/features/promo_code/cubit/promo_code_validate_cubit.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// All bloc side-effects for [CheckoutScreen], wired up in one place so the
/// screen's build method only has to describe layout.
class CheckoutBlocListeners extends StatelessWidget {
  const CheckoutBlocListeners({
    super.key,
    required this.isLoggedIn,
    required this.selectedAddress,
    this.deliveryType = DeliveryType.delivery,
    required this.onAddressResolved,
    required this.onAddressCleared,
    required this.onPromoValidated,
    required this.onPlaceOrderSuccess,
    required this.onGuestCartChanged,
    required this.child,
  });

  final bool isLoggedIn;
  final AddressData? selectedAddress;

  /// Current toggle selection — carried into the add/remove-triggered
  /// refetches below so an in-flight pickup selection isn't silently reset
  /// to 'delivery' by a fetchCart call that forgot the param.
  final DeliveryType deliveryType;
  final ValueChanged<AddressData> onAddressResolved;
  final VoidCallback onAddressCleared;
  final ValueChanged<PromoCodeData> onPromoValidated;
  final void Function(PlaceOrderSuccess state, CartData cartData)
  onPlaceOrderSuccess;
  final ValueChanged<CartState> onGuestCartChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CartActionCubit, CartActionState>(
          listener: (ctx, state) {
            if (state is CartActionSuccess) {
              // add/remove returns the full cart payload (same as get_cart),
              // so update directly without a flicker-causing refetch.
              // clear has no payload (cart == null) → refetch as before.
              final cart = state.cart;
              if (cart != null) {
                ctx.read<CartFetchCubit>().setCart(cart);
              } else {
                ctx.read<CartFetchCubit>().fetchCart(
                  addressId: selectedAddress?.id,
                  deliveryType: deliveryType,
                );
              }
            } else if (state is CartActionError) {
              if (state.fromRemove) {
                // Some backends respond with a non-1 status (treated as an
                // error by ApiClient) when a remove call empties the cart —
                // not a real failure, the cart really is now empty. Don't
                // refetch: the backend may not have finished replicating
                // the delete yet, and a refetch this early can hand back a
                // stale snapshot that still has the item, resurrecting it
                // on screen. Instead, patch the last known snapshot to an
                // empty cart directly so the bill/promo sections agree with
                // the now-empty item list.
                final fetchCubit = ctx.read<CartFetchCubit>();
                final prev = fetchCubit.state;
                if (prev is CartFetchLoaded) {
                  final prevData = prev.cart.data;
                  fetchCubit.setCart(
                    Cart(
                      status: prev.cart.status,
                      message: prev.cart.message,
                      total: 0,
                      data: prevData == null
                          ? null
                          : CartData(
                              codAllowed: prevData.codAllowed,
                              productVariantId: prevData.productVariantId,
                              quantity: prevData.quantity,
                              distance: prevData.distance,
                              timeToDeliver: prevData.timeToDeliver,
                              unlockMessage: prevData.unlockMessage,
                              unlockPromoCode: prevData.unlockPromoCode,
                              unlockPromoCodeId: prevData.unlockPromoCodeId,
                              isDeliverableAddress:
                                  prevData.isDeliverableAddress,
                              deliveryCharges: prevData.deliveryCharges,
                              surgeCharges: prevData.surgeCharges,
                              zoneAdditionalCharges:
                                  prevData.zoneAdditionalCharges,
                              totalAmount: 0,
                              userBalance: prevData.userBalance,
                              subTotal: 0,
                              savedAmount: 0,
                              minimumOrderAmount: prevData.minimumOrderAmount,
                              cart: const [],
                              additionalCharges: prevData.additionalCharges,
                              currency: prevData.currency,
                              decimalPoint: prevData.decimalPoint,
                              deliveryType: prevData.deliveryType,
                              deliveryAvailable: prevData.deliveryAvailable,
                              pickupAvailable: prevData.pickupAvailable,
                              pickup: prevData.pickup,
                            ),
                    ),
                  );
                }
                return;
              }
              ctx.read<CartFetchCubit>().fetchCart(
                addressId: selectedAddress?.id,
                deliveryType: deliveryType,
              );
              AppSnackBar.show(
                context: ctx,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
        BlocListener<CartFetchCubit, CartFetchState>(
          listener: (ctx, state) {
            if (state is CartFetchLoaded) {
              final items = state.cart.data?.cart ?? [];
              ctx.read<CartCubit>().seedFromApi(items);
            }
          },
        ),
        BlocListener<CartCubit, CartState>(
          listener: (ctx, state) {
            if (!isLoggedIn) onGuestCartChanged(state);
          },
        ),
        // Guest checkout resolves its cart (pricing, stock, zone
        // availability) via GuestCartFetchCubit, entirely separate from
        // CartCubit — without this, an item the guest cart response drops
        // or reprices never reaches CartCubit, leaving the floating cart
        // bar's count stuck on the stale local value forever.
        BlocListener<GuestCartFetchCubit, GuestCartState>(
          listener: (ctx, state) {
            if (!isLoggedIn && state is GuestCartLoaded) {
              final items = state.cart.data?.cart ?? [];
              ctx.read<CartCubit>().seedFromApi(items);
            }
          },
        ),
        BlocListener<PromoCodeValidateCubit, PromoCodeValidateState>(
          listener: (ctx, state) {
            // Only reached by address-change revalidation — the actual apply
            // flow pops promo_code_screen with a result before this listener
            // would ever get a chance to react.
            if (state is PromoCodeValidateSuccess) {
              onPromoValidated(state.data);
            } else if (state is PromoCodeValidateError) {
              AppSnackBar.show(
                context: ctx,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
        BlocListener<AddressCubit, PaginationState<AddressData>>(
          listener: (ctx, state) {
            if (state is! PaginationLoaded<AddressData>) return;
            final current = selectedAddress;

            // No saved addresses left — drop any stale selection. Also
            // covers the first-load case where the user has no addresses
            // at all: the cart still needs a fetch (without addressId) so
            // the screen doesn't stay stuck on its loading state.
            if (state.data.isEmpty) {
              onAddressCleared();
              return;
            }

            if (current == null) {
              // Pickup's address is optional (choose saved or type manually)
              // — don't force the default on the customer, let the bottom
              // bar's choice buttons show instead. Delivery still needs one
              // auto-picked so checkout isn't stuck with nothing selected.
              if (deliveryType == DeliveryType.pickup) return;
              final def = state.data.firstWhere(
                (a) => a.isDefault == '1',
                orElse: () => state.data.first,
              );
              onAddressResolved(def);
              return;
            }

            final idx = state.data.indexWhere((a) => a.id == current.id);
            if (idx == -1) {
              // Selected address was deleted — fall back to default/first.
              final def = state.data.firstWhere(
                (a) => a.isDefault == '1',
                orElse: () => state.data.first,
              );
              onAddressResolved(def);
            } else if (state.data[idx].latitude != current.latitude) {
              // Address was edited (coordinates moved) — refresh selection.
              onAddressResolved(state.data[idx]);
            }
          },
        ),
        BlocListener<PlaceOrderCubit, PlaceOrderState>(
          listener: (ctx, state) {
            if (state is PlaceOrderSuccess) {
              final cartState = ctx.read<CartFetchCubit>().state;
              final cd = cartState is CartFetchLoaded
                  ? cartState.cart.data
                  : null;
              if (cd != null) onPlaceOrderSuccess(state, cd);
            } else if (state is PlaceOrderError) {
              AppSnackBar.show(
                context: ctx,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
      ],
      child: child,
    );
  }
}
