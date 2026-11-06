import 'package:customer/features/gifting/gift_details_section.dart';
import 'package:flutter/rendering.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/pickup_store_details.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/features/cart/cubit/cart_fetch_cubit.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/checkout/cubit/place_order_cubit.dart';
import 'package:customer/features/checkout/models/billing_address_model.dart';
import 'package:customer/features/checkout/widgets/checkout_bill_section.dart';
import 'package:customer/features/checkout/widgets/checkout_cart_items_section.dart';
import 'package:customer/features/checkout/widgets/checkout_order_note_section.dart';
import 'package:customer/features/checkout/widgets/checkout_place_order_bar.dart';
import 'package:customer/features/checkout/widgets/checkout_promo_section.dart';
import 'package:customer/features/checkout/widgets/checkout_recommendations_section.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/features/checkout/widgets/checkout_wallet_section.dart';
import 'package:customer/features/checkout/utils/checkout_totals.dart';
import 'package:customer/features/payment_method/cubit/payment_cubit.dart';
import 'package:customer/features/payment_method/cubit/payment_methods_cubit.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'dart:io';
import 'package:customer/features/checkout/utils/checkout_variant_id.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The logged-in checkout body: item list, promo/wallet/note sections, bill
/// summary and the sticky place-order bar. Rendered once [CartFetchLoaded]
/// resolves with a non-empty cart.
class CheckoutLoadedBody extends StatelessWidget {
  const CheckoutLoadedBody({
    super.key,
    required this.cartData,
    required this.currency,
    required this.addressLat,
    required this.addressLng,
    required this.appliedPromo,
    required this.useWallet,
    required this.selectedAddress,
    required this.selectedPayment,
    this.deliveryType = DeliveryType.delivery,
    required this.onRemovePromo,
    required this.onBrowseCodes,
    required this.onWalletToggle,
    required this.onNoteChanged,
    this.buyerTaxSection,
    required this.onPlaceOrder,
    required this.onChooseAddress,
    required this.onChoosePayment,
    required this.billingSameAsShipping,
    required this.billingAddress,
    required this.onBillingToggle,
    required this.onEditBillingAddress,
    this.prescriptions = const {},
    this.onPrescriptionPicked,
    this.onPrescriptionRemoved,
    this.prescriptionKeyOf,
    this.onUploadPrescriptionRequested,
    this.recommendationsKey,
    this.onAddMoreItems,
    this.scrollController,
  });

  final CartData cartData;
  final String currency;
  final String addressLat;
  final String addressLng;
  final PromoCodeData? appliedPromo;
  final bool useWallet;
  final AddressData? selectedAddress;
  final PaymentMethodItem? selectedPayment;

  /// 'delivery' | 'pickup' — pickup needs no shipping address; the
  /// place-order bar shows the pickup store instead.
  final DeliveryType deliveryType;

  bool get _isPickup => deliveryType == DeliveryType.pickup;
  final VoidCallback onRemovePromo;
  final ValueChanged<String> onBrowseCodes;
  final ValueChanged<bool> onWalletToggle;
  final ValueChanged<String> onNoteChanged;

  /// "Business details" — buyer tax number for the billed party,
  /// shown beside the order note (it's typed per order, like the note).
  /// Built by the screen, which owns the country spec and typed values.
  final Widget? buyerTaxSection;
  final VoidCallback onPlaceOrder;
  final VoidCallback onChooseAddress;
  final ValueChanged<bool> onChoosePayment;
  final bool billingSameAsShipping;
  final BillingAddressData? billingAddress;
  final ValueChanged<bool> onBillingToggle;
  final VoidCallback onEditBillingAddress;

  /// Picked prescription files keyed by product variant id (medical products).
  final Map<String, File> prescriptions;
  final void Function(String variantId, File file)? onPrescriptionPicked;
  final void Function(String variantId)? onPrescriptionRemoved;

  /// Returns the scroll-target key for a variant's prescription tile.
  final GlobalKey Function(String variantId)? prescriptionKeyOf;

  /// Called with the variant id to scroll to when the "Upload Prescription"
  /// CTA is tapped.
  final ValueChanged<String>? onUploadPrescriptionRequested;

  /// Scroll target for the recommendations section, and the "Forgot
  /// something? Add More Items" tap handler.
  final GlobalKey? recommendationsKey;
  final VoidCallback? onAddMoreItems;

  // Drives the app bar's scroll-shadow.
  final ScrollController? scrollController;

  /// Variant id of the first medical item still missing its mandatory
  /// prescription upload, or null if none is missing.
  String? get _firstMissingRequiredVariantId {
    for (final item in cartData.cart ?? <ProductDataModel>[]) {
      if (!item.requiresPrescription) continue;
      final variantId = resolveCheckoutVariantId(item);
      if (prescriptions[variantId] == null) return variantId;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Not-deliverable only applies once an address is actually selected: with
    // no address the user must pick one first (the place-order bar shows the
    // "choose address" prompt), so sections stay visible until then.
    final notDeliverable =
        !_isPickup &&
        selectedAddress != null &&
        cartData.isDeliverableAddress == 0;
    final saved = resolveCheckoutSavedAmount(
      cartData: cartData,
      appliedPromo: appliedPromo,
    );
    return BlocSelector<PlaceOrderCubit, PlaceOrderState, bool>(
      selector: (s) => s is PlaceOrderLoading,
      builder: (context, isPlacing) {
        // Gateway attempt (initiate_transaction + SDK/webview launch) runs
        // straight off this screen once the order is placed — keep the
        // button loading through that too, not just order creation.
        final isPaying =
            context.watch<PaymentCubit>().state is PaymentProcessing;
        final loading = isPlacing || isPaying;
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: context.cs.primary,
                onRefresh: () async {
                  final addressCubit = context.read<AddressCubit>();
                  final paymentCubit = context.read<PaymentMethodsCubit>();
                  await context.read<CartFetchCubit>().fetchCart(
                    latitude: addressLat,
                    longitude: addressLng,
                    addressId: selectedAddress?.id,
                    deliveryType: deliveryType,
                  );
                  addressCubit.refresh();
                  paymentCubit.loadPaymentMethods();
                },
                child: ScrollConfiguration(
                  // Material3's default stretch overscroll effect visually
                  // scales the whole viewport (including the pinned sticky
                  // banner) when pulled past the top edge — looks like the
                  // banner dips behind the app bar. Same fix needed on
                  // Android as the iOS bounce; RefreshIndicator's pull
                  // gesture doesn't depend on this indicator.
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(overscroll: false),
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    // Checkout's content is short and finite — keep every
                    // child built regardless of scroll position, otherwise
                    // tiles that fall outside the default cacheExtent (e.g.
                    // the prescription upload tile, when scrolled to the
                    // bottom) get unmounted and their GlobalKey.currentContext
                    // goes null, silently breaking Scrollable.ensureVisible.
                    // A literal `double.infinity` here makes the viewport
                    // compute a non-finite paint/semantics rect and crashes
                    // with accessibility/semantics enabled — use a large
                    // finite value instead (content never gets close to it).
                    scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
                    slivers: [
                      // Pinned so it docks flush under the app bar instead of
                      // scrolling away — its own delegate morphs the pill from
                      // floating/rounded to flat/edge-to-edge with a shadow as
                      // it reaches the top, instead of just snapping there.
                      if (saved > 0)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickySavedBannerDelegate(
                            amountText:
                                '$currency${saved.formatPrice(cartData.decimalPoint ?? 2)}',
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          ThemeConstants.paddingL,
                          saved > 0 ? 0 : ThemeConstants.paddingM,
                          ThemeConstants.paddingL,
                          0,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (_isPickup) ...[
                              _PickupStoreCard(pickup: cartData.pickup),
                              AppSpacing.h12,
                            ],
                            CheckoutCartItemsSection(
                              cartData: cartData,
                              currency: currency,
                              prescriptions: prescriptions,
                              onPrescriptionPicked: onPrescriptionPicked,
                              onPrescriptionRemoved: onPrescriptionRemoved,
                              prescriptionKeyOf: prescriptionKeyOf,
                              onAddMoreItems: onAddMoreItems,
                            ),
                            AppSpacing.h12,
                            // Delivery isn't available for the selected address
                            // (is_deliverable_address == 0): the place-order bar
                            // already surfaces the notice next to the address strip
                            // — hide promo / wallet / note / bill here, none apply
                            // until a serviceable address is picked.
                            if (notDeliverable)
                              const SizedBox.shrink()
                            else ...[
                              CheckoutRecommendationsSection(
                                key: recommendationsKey,
                              ),
                              CheckoutPromoSection(
                                appliedPromo: appliedPromo,
                                onRemove: onRemovePromo,
                                onBrowseCodes: () => onBrowseCodes(
                                  (cartData.subTotal ?? 0).toString(),
                                ),
                                unlockMessage: cartData.unlockMessage,
                                unlockPromoCode: cartData.unlockPromoCode,
                              ),
                              AppSpacing.h12,
                              if (cartData.userBalance != null &&
                                  (cartData.userBalance ?? 0.0) > 0)
                                CheckoutWalletSection(
                                  walletBalance: cartData.userBalance ?? 0.0,
                                  // Post-promo total, same figure the place-order bar
                                  // and payload actually charge against — otherwise a
                                  // percentage promo makes this section's "wallet
                                  // used" disagree with what's really deducted.
                                  orderAmount: resolveCheckoutPostPromoTotal(
                                    cartData: cartData,
                                    appliedPromo: appliedPromo,
                                  ),
                                  currency: currency,
                                  isWalletSelected: useWallet,
                                  onWalletToggle: onWalletToggle,
                                ),
                              if (cartData.userBalance != null &&
                                  (cartData.userBalance ?? 0) > 0)
                                AppSpacing.h12,
                              const GiftDetailsSection(),
                              AppSpacing.h12,
                              if (SettingsHiveBox.instance.channel ==
                                  AppConstants.quick) ...[
                                CheckoutOrderNoteSection(
                                  onNoteChanged: onNoteChanged,
                                ),
                                AppSpacing.h12,
                              ],
                              ?buyerTaxSection,
                              CheckoutBillDetailsSection(
                                cartData: cartData,
                                currency: currency,
                                appliedPromo: appliedPromo,
                                useWallet: useWallet,
                                isPickup: _isPickup,
                              ),
                            ],
                            AppSpacing.h100,
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            CheckoutPlaceOrderBar(
              cartData: cartData,
              currency: currency,
              isLoading: loading,
              selectedAddress: selectedAddress,
              selectedPayment: selectedPayment,
              isPickup: _isPickup,
              useWallet: useWallet,
              appliedPromo: appliedPromo,
              onPlaceOrder: onPlaceOrder,
              onChooseAddress: onChooseAddress,
              onChoosePayment: () => onChoosePayment(cartData.codAllowed == 1),
              billingSameAsShipping: billingSameAsShipping,
              billingAddress: billingAddress,
              onBillingToggle: onBillingToggle,
              onEditBillingAddress: onEditBillingAddress,
              hasMissingRequiredPrescription:
                  !notDeliverable && _firstMissingRequiredVariantId != null,
              onUploadPrescription: () {
                final variantId = _firstMissingRequiredVariantId;
                if (variantId != null) {
                  onUploadPrescriptionRequested?.call(variantId);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

/// Pickup store details, shown once in the checkout body (below the saved
/// amount banner) instead of inside the bottom bar — the bar only shows the
/// billing checkbox for pickup now.
class _PickupStoreCard extends StatelessWidget {
  const _PickupStoreCard({required this.pickup});

  final CartPickupInfo? pickup;

  @override
  Widget build(BuildContext context) {
    return CheckoutCard(
      child: PickupStoreDetails(
        storeName: pickup?.branchName,
        address: pickup?.address,
        latitude: pickup?.latitude,
        longitude: pickup?.longitude,
        contactNumber: pickup?.contactNumber,
        preparationTime: pickup?.preparationTime,
        preparationMinutes: pickup?.preparationMinutes,
        isOpenNow: pickup?.isOpenNow,
      ),
    );
  }
}

/// Pinned sticky header for the "you saved" banner — same rounded/gradient
/// pill as [SavedAmountBannerStyle.rounded] while floating at the top of the
/// list, morphing smoothly into a flat, edge-to-edge, shadowed bar as it
/// reaches (and then stays docked under) the app bar, instead of just
/// snapping into its pinned position.
class _StickySavedBannerDelegate extends SliverPersistentHeaderDelegate {
  _StickySavedBannerDelegate({required this.amountText});

  final String amountText;

  static const double _bannerHeight = 52;
  static const double _topGap = ThemeConstants.paddingM;
  static const double _bottomGap = ThemeConstants.spaceM;

  @override
  double get minExtent => _topGap + _bannerHeight + _bottomGap;

  @override
  double get maxExtent => _topGap + _bannerHeight + _bottomGap;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Fully flat/edge-to-edge/shadowed as soon as the top gap alone has
    // scrolled away — reads as a quick, smooth settle rather than a snap,
    // then stays flat for the rest of the scroll while pinned.
    final progress = (shrinkOffset / _topGap).clamp(0.0, 1.0);
    final horizontalMargin = ThemeConstants.paddingL * (1 - progress);
    final text =
        '${context.translate(LanguageLabelKeys.youSaved)} $amountText ${context.translate(LanguageLabelKeys.onThisOrder)}';

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        horizontalMargin,
        _topGap * (1 - progress),
        horizontalMargin,
        _bottomGap,
      ),
      child: Container(
        height: _bannerHeight,
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
        ),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * (1 - progress)),
          // Blended against the surface color (not left translucent) —
          // pinned headers paint above the list, so a plain alpha gradient
          // lets the scrolling content underneath show through once stuck.
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerEnd,
            end: AlignmentDirectional.centerStart,
            colors: [
              Color.alphaBlend(
                context.cs.primary.withValues(alpha: 0.22),
                context.cs.surface,
              ),
              Color.alphaBlend(
                context.cs.primary.withValues(alpha: 0.08),
                context.cs.surface,
              ),
            ],
          ),
          // offset.dy >= blurRadius so the blur only spreads downward —
          // otherwise it bleeds a few px above the top edge, into the app
          // bar it's flush against once fully stuck.
          boxShadow: progress <= 0
              ? null
              : [
                  BoxShadow(
                    color: context.cs.shadow.withValues(alpha: 0.12 * progress),
                    blurRadius: 6,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: AppText(
          text,
          maxLines: 1,
          overflow: .ellipsis,
          style: context.tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.primary,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySavedBannerDelegate oldDelegate) =>
      oldDelegate.amountText != amountText;
}
