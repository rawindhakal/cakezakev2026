import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'dart:async';
import 'dart:io';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/features/checkout/widgets/checkout_delivery_eta_section.dart';
import 'package:customer/features/checkout/widgets/checkout_prescription_tile.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/features/checkout/utils/checkout_variant_id.dart';
import 'package:customer/features/products/widgets/cart_addon_list.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/product_variant_sheet.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/utils/variant_attributes_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CheckoutCartItemsSection extends StatelessWidget {
  const CheckoutCartItemsSection({
    super.key,
    required this.cartData,
    required this.currency,
    this.prescriptions = const {},
    this.onPrescriptionPicked,
    this.onPrescriptionRemoved,
    this.prescriptionKeyOf,
    this.onAddMoreItems,
  });

  final CartData cartData;
  final String currency;

  /// Picked prescription files keyed by product variant id. Only relevant for
  /// medical products (product_type == 5).
  final Map<String, File> prescriptions;
  final void Function(String variantId, File file)? onPrescriptionPicked;
  final void Function(String variantId)? onPrescriptionRemoved;
  final GlobalKey Function(String variantId)? prescriptionKeyOf;

  // "Forgot something? Add More Items" tap — destination to be wired once
  // decided (e.g. back to the product listing / cart).
  final VoidCallback? onAddMoreItems;

  @override
  Widget build(BuildContext context) {
    final items = cartData.cart ?? [];
    // Cart response's own delivery_type reflects the mode it was actually
    // priced in (server may have fallen back from what was requested), so
    // this reads straight off cartData rather than a separately-tracked flag.
    final isPickup =
        DeliveryType.fromApiValue(cartData.deliveryType) == DeliveryType.pickup;
    return CheckoutCard(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          CheckoutDeliveryEtaSection(
            distance: cartData.distance,
            timeToDeliver: cartData.timeToDeliver,
            estimatedDeliveryDate: cartData.estimatedDeliveryDate,
            itemCount: items.length,
            isPickup: isPickup,
            pickupPreparationTime: cartData.pickup?.preparationTime,
          ),
          Divider(height: 0.5),
          AppSpacing.h12,
          ...items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            final variantId = resolveCheckoutVariantId(e.value);
            // Add-on module: two lines of one dish with different
            // answers share a variant id — key them apart and read each
            // line's own qty instead of the variant's summed count.
            final isAddonLineRow = e.value.isAddonLine;
            return BlocSelector<CartCubit, CartState, int>(
              key: ValueKey(
                isAddonLineRow
                    ? CartState.addonLineKey(variantId, e.value.addonSelections)
                    : variantId,
              ),
              selector: (state) => isAddonLineRow
                  ? addonCartLineQty(e.value)
                  : state.countFor(variantId),
              builder: (context, qty) {
                // Qty hits 0 — drop the row entirely instead of showing "0".
                if (qty <= 0) return const SizedBox.shrink();
                return Column(
                  children: [
                    CheckoutCartItemTile(
                      item: e.value,
                      currency: currency,
                      prescriptionFile: prescriptions[variantId],
                      onPrescriptionPicked: onPrescriptionPicked == null
                          ? null
                          : (file) => onPrescriptionPicked!(variantId, file),
                      onPrescriptionRemoved: onPrescriptionRemoved == null
                          ? null
                          : () => onPrescriptionRemoved!(variantId),
                      prescriptionKey: prescriptionKeyOf?.call(variantId),
                    ),
                    if (!isLast)
                      Divider(
                        height: 20,
                        thickness: 1,
                        color: context.cs.outlineVariant,
                      ),
                  ],
                );
              },
            );
          }),
          AppSpacing.h12,
          Divider(height: 0.5),
          AppSpacing.h12,
          InkWell(
            borderRadius: AppRadius.r8,
            onTap: onAddMoreItems,
            child: Row(
              mainAxisAlignment: .center,
              mainAxisSize: .max,
              children: [
                AppText(
                  context.translate(LanguageLabelKeys.forgotSomething),
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurface,
                  ),
                ),
                AppSpacing.w4,
                AppText(
                  context.translate(LanguageLabelKeys.addMoreItems),
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutCartItemTile extends StatelessWidget {
  const CheckoutCartItemTile({
    super.key,
    required this.item,
    required this.currency,
    this.prescriptionFile,
    this.onPrescriptionPicked,
    this.onPrescriptionRemoved,
    this.prescriptionKey,
  });

  final ProductDataModel item;
  final String currency;
  final File? prescriptionFile;
  final ValueChanged<File>? onPrescriptionPicked;
  final VoidCallback? onPrescriptionRemoved;
  final GlobalKey? prescriptionKey;

  static void _removeItem(BuildContext context, ProductDataModel item) {
    final variantId = resolveCheckoutVariantId(item);
    final cart = context.read<CartCubit>();
    if (item.isAddonLine) {
      // Add-on module: drop only this line — its answers tell the
      // server which line of the dish to remove.
      final lineQty = addonCartLineQty(item);
      if (!AuthHiveBox.instance.isLoggedIn) {
        cart.removeGuestAddonLine(
          variantId: variantId,
          addons: item.addonSelections,
          count: lineQty,
        );
        return;
      }
      final price = (item.discountedPrice ?? item.price ?? 0).toDouble();
      cart.setQuantity(
        variantId,
        price,
        cart.state.countFor(variantId) - lineQty,
      );
      _removeAddonLineUnits(context, item, variantId, lineQty);
      return;
    }
    final qty = cart.state.countFor(variantId);
    cart.removeAll(variantId);
    if (AuthHiveBox.instance.isLoggedIn && qty > 0) {
      context.read<CartActionCubit>().removeFromCart(
        productId: item.id?.toString() ?? '',
        productVariantId: variantId,
        qty: qty,
      );
    }
  }

  /// Add-on module: cart/remove decrements a line by one per call, so
  /// clearing a whole line of n units takes n calls with its answers.
  static Future<void> _removeAddonLineUnits(
    BuildContext context,
    ProductDataModel item,
    String variantId,
    int units,
  ) async {
    final action = context.read<CartActionCubit>();
    for (var i = 0; i < units; i++) {
      await action.removeFromCart(
        productId: item.id?.toString() ?? '',
        productVariantId: variantId,
        qty: 1,
        addons: item.addonSelections,
      );
      if (action.state is CartActionError) break;
    }
  }

  /// Opens the peek-card product detail (expands to full screen on scroll).
  void _openProductDetail(BuildContext context) {
    final productId = item.id;
    if (productId == null) return;
    AppNavigator.pushNamed(
      context,
      RouteNames.productDetail,
      arguments: ProductDetailArgs(
        productId: productId,
        imageUrl: item.images?.coverUrl,
      ),
    );
  }

  /// Add-on module: Zomato-style "Edit ›" under the answers — reopens the
  /// customise sheet pre-filled with this line.
  Widget _editAddonsLink(BuildContext context) {
    // Same pill as the profile header's Edit, tinted primary for checkout.
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: ThemeConstants.paddingXS),
      child: GestureDetector(
        onTap: () => showAddonLineEditSheet(
          context: context,
          item: item,
          variantId: resolveCheckoutVariantId(item),
          qty: addonCartLineQty(item),
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingM,
            vertical: ThemeConstants.paddingXS,
          ),
          decoration: AppDecorations.box(
            color: context.cs.primary.withValues(alpha: 0.1),
            borderRadius: AppRadius.r8,
          ),
          child: Row(
            mainAxisSize: .min,
            spacing: ThemeConstants.spaceXS,
            children: [
              AppSvgIcon(
                AssetsConstants.editIcon,
                size: ThemeConstants.iconXS,
                color: context.cs.primary,
              ),
              AppText(
                context.translate(LanguageLabelKeys.edit),
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgSize = context.screenWidth * 0.19;
    final price = (item.price ?? 0).toDouble();
    final discounted = item.discountedPrice ?? 0;
    final hasDiscount = discounted > 0 && discounted < price;
    final displayPrice = hasDiscount ? discounted : price;
    final dp = item.decimalPoint ?? 0;
    final name = (item.name ?? '').trim();
    final title = name.isNotEmpty ? name : item.productName ?? '';
    final variant =
        VariantAttributesFormatter.format(
          item.variants?.first.variantAttributes,
        ) ??
        "";
    final slabMessage = (item.slabDiscountMessage ?? '').trim();
    final isOutOfStock = item.isOutOfStock;

    final showPrescription =
        item.isMedicalProduct && !isOutOfStock && onPrescriptionPicked != null;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: isOutOfStock ? 0.5 : 1,
              child: Row(
                crossAxisAlignment: .start,
                spacing: ThemeConstants.spaceM,
                children: [
                  GestureDetector(
                    onTap: () => _openProductDetail(context),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.r10,
                          child: Container(
                            decoration: AppDecorations.box(
                              color: context.cs.surfaceContainer,
                              border: Border.all(
                                color: context.cs.outline.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                              borderRadius: AppRadius.r10,
                            ),
                            child: AppNetworkImage(
                              url:
                                  item.variants?.first.image ??
                                  item.images?.coverUrl ??
                                  '',
                              width: imgSize,
                              height: imgSize,
                              fit: BoxFit.contain,
                              memCacheWidth: 144,
                              memCacheHeight: 144,
                              borderRadius: AppRadius.r10,
                              errorIconSize: 20,
                            ),
                          ),
                        ),
                        if (isOutOfStock)
                          PositionedDirectional(
                            top: 0,
                            start: 0,
                            child: Container(
                              decoration: AppDecorations.box(
                                color: context.cs.inverseSurface,
                                borderRadius:
                                    const BorderRadiusDirectional.only(
                                      topStart: Radius.circular(10),
                                      bottomEnd: Radius.circular(4),
                                    ),
                              ),
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: ThemeConstants.paddingXS,
                                vertical: 3,
                              ),
                              child: AppText(
                                context.translate(LanguageLabelKeys.soldOut),
                                style: context.tt.labelSmall?.copyWith(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: context.cs.onInverseSurface,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Swiggy/Zomato-style: name beside the stepper, the
                  // variant beside the price, add-ons full width below —
                  // so nothing waits under the taller stepper column.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      mainAxisSize: .min,
                      children: [
                        Row(
                          crossAxisAlignment: .center,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _openProductDetail(context),
                                child: Text.rich(
                                  ProductTypeIcon.nameSpan(
                                    productType: item.productType,
                                    name: title,
                                    size: ThemeConstants.iconXS,
                                  ),
                                  style: context.tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: .ellipsis,
                                ),
                              ),
                            ),
                            AppSpacing.w8,
                            if (isOutOfStock)
                              InkWell(
                                borderRadius: AppRadius.r8,
                                onTap: () => _removeItem(context, item),
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: ThemeConstants.paddingS,
                                  ),
                                  child: AppSvgIcon(
                                    AssetsConstants.closeIcon,
                                    size: ThemeConstants.iconXS,
                                    color: context.cs.onSurface,
                                  ),
                                ),
                              )
                            else if (item.isAddonLine)
                              // Add-on module: per-line stepper.
                              AddonCartLineQtyControl(item: item)
                            else
                              CheckoutQtyControl(item: item),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: .baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: AppText(
                                variant,
                                style: context.tt.bodySmall?.copyWith(
                                  color: context.cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: .ellipsis,
                              ),
                            ),
                            AppSpacing.w8,
                            BlocSelector<CartCubit, CartState, int>(
                              selector: (state) => item.isAddonLine
                                  ? addonCartLineQty(item)
                                  : state.countFor(
                                      resolveCheckoutVariantId(item),
                                    ),
                              builder: (context, qty) => Row(
                                mainAxisSize: .min,
                                crossAxisAlignment: .baseline,
                                textBaseline: TextBaseline.alphabetic,
                                spacing: ThemeConstants.spaceXS,
                                children: [
                                  if (hasDiscount)
                                    AppText(
                                      '${item.currency}${(price * qty).formatPrice(dp)}',
                                      style: context.tt.bodySmall?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: context.cs.onSurface.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                  AppText(
                                    '${item.currency}${(displayPrice * qty).formatPrice(dp)}',
                                    style: context.tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Add-on module: chosen options nested under the
                        // dish (a linked product like a drink stays here,
                        // never its own line), using the full width.
                        if (item.isAddonLine) ...[
                          AppSpacing.h2,
                          CartAddonList(
                            addons: item.addons!,
                            addonTotal: item.addonTotal ?? 0,
                            currency: item.currency ?? currency,
                            decimalPoint: dp,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (slabMessage.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: imgSize + ThemeConstants.spaceM,
            ),
            child: InkWell(
              borderRadius: AppRadius.r8,
              onTap: () {},
              child: Row(
                mainAxisSize: .min,
                spacing: ThemeConstants.spaceXS,
                children: [
                  AppSvgIcon(
                    AssetsConstants.lockIcon,
                    color: context.cs.onSecondaryContainer,
                    size: ThemeConstants.iconXS,
                  ),
                  Flexible(
                    child: AppText(
                      slabMessage,
                      style: context.tt.labelSmall?.copyWith(
                        color: context.cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ),
                  AppSvgIcon(
                    AssetsConstants.arrowRightIcon,
                    color: context.cs.onSecondaryContainer,
                    size: ThemeConstants.iconXS,
                  ),
                ],
              ),
            ),
          ),
        // Add-on module: an option stopped being servable after it was
        // added — checkout will refuse, so warn here, not at payment.
        if (item.hasUnavailableAddons == 1)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: imgSize + ThemeConstants.spaceM,
              top: ThemeConstants.spaceXS,
            ),
            child: AppText(
              context.translate(LanguageLabelKeys.addonUnavailableWarning),
              style: context.tt.labelSmall?.copyWith(
                color: context.cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (showPrescription)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: imgSize + ThemeConstants.spaceM,
            ),
            child: CheckoutPrescriptionTile(
              key: prescriptionKey,
              item: item,
              file: prescriptionFile,
              onPicked: onPrescriptionPicked!,
              onRemove: onPrescriptionRemoved ?? () {},
            ),
          ),
        // Add-on module: "Edit ›" closes the line, under every detail.
        if (item.isAddonLine && !isOutOfStock)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: imgSize + ThemeConstants.spaceM,
            ),
            child: _editAddonsLink(context),
          ),
      ],
    );
  }
}

class CheckoutQtyControl extends StatefulWidget {
  const CheckoutQtyControl({super.key, required this.item});

  final ProductDataModel item;

  @override
  State<CheckoutQtyControl> createState() => _CheckoutQtyControlState();
}

class _CheckoutQtyControlState extends State<CheckoutQtyControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  // Debounced server sync: coalesce a burst of taps into a single API call.
  Timer? _syncDebounce;
  int? _baseQty; // server-confirmed qty captured at the start of a tap burst
  CartCubit? _cartCubit;
  CartActionCubit? _actionCubit;

  ProductDataModel get item => widget.item;

  String get _variantId => resolveCheckoutVariantId(item);

  bool get _hasLimit => (item.totalAllowedQuantity ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(_scaleCtrl);
  }

  @override
  void dispose() {
    // Persist any pending change before the widget goes away.
    if (_syncDebounce?.isActive ?? false) {
      _syncDebounce!.cancel();
      _flushSync();
    }
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), _flushSync);
  }

  /// Sends the net change accumulated during the burst as one request.
  void _flushSync() {
    _syncDebounce = null;
    final base = _baseQty;
    final cart = _cartCubit;
    final action = _actionCubit;
    _baseQty = null;
    if (base == null || cart == null || action == null) return;
    final target = cart.state.countFor(_variantId);
    final delta = target - base;
    if (delta == 0) return;
    if (delta > 0) {
      action.addToCart(
        productId: item.id?.toString() ?? '',
        productVariantId: _variantId,
        qty: target,
      );
    } else {
      action.removeFromCart(
        productId: item.id?.toString() ?? '',
        productVariantId: _variantId,
        qty: -delta,
      );
    }
  }

  void _showLimitWarning(BuildContext context) {
    AppSnackBar.show(
      context: context,
      message: context.translate(LanguageLabelKeys.maxAllowedQuantityReached),
      type: SnackBarType.warning,
    );
  }

  void _onRemove(BuildContext context) {
    final isLoggedIn = AuthHiveBox.instance.isLoggedIn;
    final cart = context.read<CartCubit>();
    if (cart.state.countFor(_variantId) <= 0) return;
    AppHaptics.tap();
    _scaleCtrl.forward(from: 0.0);
    final price = (item.discountedPrice ?? item.price ?? 0).toDouble();
    if (isLoggedIn) {
      _cartCubit = cart;
      _actionCubit = context.read<CartActionCubit>();
      _baseQty ??= cart.state.countFor(_variantId);
    }
    cart.remove(_variantId, price);
    if (isLoggedIn) _scheduleSync();
  }

  void _onAdd(BuildContext context) {
    if (item.isOutOfStock) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.outOfStock),
        type: SnackBarType.warning,
      );
      return;
    }
    final isLoggedIn = AuthHiveBox.instance.isLoggedIn;
    final cart = context.read<CartCubit>();
    final localQty = cart.state.countFor(_variantId);

    if (_hasLimit && localQty >= (item.totalAllowedQuantity ?? 0)) {
      _showLimitWarning(context);
      return;
    }
    final maxCartItems = SettingsHiveBox.instance.maxCartItemsCount;
    if (maxCartItems > 0 && cart.state.totalItems >= maxCartItems) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.maxCartItemsReached),
        type: SnackBarType.warning,
      );
      return;
    }

    AppHaptics.tap();
    _scaleCtrl.forward(from: 0.0);
    final price = (item.discountedPrice ?? item.price ?? 0).toDouble();
    final imageUrl = item.variants?.first.image ?? item.images?.coverUrl ?? '';
    if (isLoggedIn) {
      _cartCubit = cart;
      _actionCubit = context.read<CartActionCubit>();
      _baseQty ??= localQty;
    }
    cart.add(_variantId, price, imageUrl: imageUrl);
    if (isLoggedIn) _scheduleSync();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        height: 28,
        decoration: AppDecorations.box(
          border: Border.all(color: context.cs.primary),
          borderRadius: AppRadius.r8,
        ),
        child: Row(
          mainAxisSize: .min,
          children: [
            GestureDetector(
              onTap: () => _onRemove(context),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: AppText(
                  context.translate(LanguageLabelKeys.remove),
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add-on module: qty of one add-on cart line as the server reports it
/// (same field [CartCubit.seedFromApi] reads).
int addonCartLineQty(ProductDataModel item) => item.variants?.isNotEmpty == true
    ? (item.variants!.first.quantity ?? 0)
    : 0;

/// Add-on module: stepper for one add-on cart line. Every call carries
/// the line's own answers so the server hits this line and not another
/// line of the same dish. No local optimistic update — the add/remove
/// response is the full cart, which the checkout listener applies.
class AddonCartLineQtyControl extends StatefulWidget {
  const AddonCartLineQtyControl({super.key, required this.item});

  final ProductDataModel item;

  @override
  State<AddonCartLineQtyControl> createState() =>
      _AddonCartLineQtyControlState();
}

class _AddonCartLineQtyControlState extends State<AddonCartLineQtyControl> {
  bool _busy = false;

  ProductDataModel get item => widget.item;

  Future<void> _change(int delta) async {
    if (_busy) return;
    final qty = addonCartLineQty(item);
    final action = context.read<CartActionCubit>();
    final cart = context.read<CartCubit>();
    if (delta > 0) {
      final limit = item.totalAllowedQuantity ?? 0;
      if (limit > 0 &&
          context.read<CartCubit>().state.countFor(
                resolveCheckoutVariantId(item),
              ) >=
              limit) {
        AppSnackBar.show(
          context: context,
          message: context.translate(
            LanguageLabelKeys.maxAllowedQuantityReached,
          ),
          type: SnackBarType.warning,
        );
        return;
      }
    }
    AppHaptics.tap();
    if (!AuthHiveBox.instance.isLoggedIn) {
      // Guest: change the local line; the checkout screen re-prices it
      // through guest_cart (items) on the CartCubit change.
      final variantId = resolveCheckoutVariantId(item);
      if (delta > 0) {
        cart.addGuestAddonLine(
          productId: item.id?.toString() ?? '',
          variantId: variantId,
          price: (item.discountedPrice ?? item.price ?? 0).toDouble(),
          addons: item.addonSelections,
        );
      } else {
        cart.removeGuestAddonLine(
          variantId: variantId,
          addons: item.addonSelections,
        );
      }
      return;
    }
    setState(() => _busy = true);
    if (delta > 0) {
      // cart/add takes the line's resulting qty.
      await action.addToCart(
        productId: item.id?.toString() ?? '',
        productVariantId: resolveCheckoutVariantId(item),
        qty: qty + 1,
        addons: item.addonSelections,
      );
    } else {
      // cart/remove decrements this line by one.
      await action.removeFromCart(
        productId: item.id?.toString() ?? '',
        productVariantId: resolveCheckoutVariantId(item),
        qty: 1,
        addons: item.addonSelections,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final state = action.state;
    // "Not enough stock" etc. come back as status 0 — show them.
    if (state is CartActionError && !state.fromRemove) {
      AppSnackBar.show(
        context: context,
        message: state.message,
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _busy
        ? context.cs.primary.withValues(alpha: 0.35)
        : context.cs.primary;
    return Container(
      height: 28,
      decoration: AppDecorations.box(
        border: Border.all(color: context.cs.primary),
        borderRadius: AppRadius.r8,
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          GestureDetector(
            onTap: () => _change(-1),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AppText(
                context.translate(LanguageLabelKeys.remove),
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutQtyBtn extends StatelessWidget {
  const CheckoutQtyBtn({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final String icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingXS,
          vertical: ThemeConstants.paddingXS,
        ),
        child: AppSvgIcon(icon, size: ThemeConstants.iconXS, color: color),
      ),
    );
  }
}
