import 'package:customer/commons/widgets/store_closed_dialog.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/products/cubit/serviceability_cubit.dart';
import 'package:customer/commons/widgets/cart_button.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/features/products/widgets/addon_section.dart';
import 'package:customer/commons/widgets/notify_me_button.dart';
import 'package:customer/features/products/models/product_detail_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductDetailBottomBar extends StatelessWidget {
  final ProductDetailDataModel product;
  final int selectedVariantIndex;

  /// Fired only on the very first add (cart count 0→1) for this variant —
  /// used to auto-scroll down to the Upsell section.
  final VoidCallback? onFirstAddToCart;

  /// 0 (peeked) → 1 (fully expanded). The peeked card is already floated
  /// off the screen edge by an outer margin that accounts for the device's
  /// bottom safe-area inset, so adding the full inset here too would
  /// double-count it and make the bar look oversized. At full expansion
  /// that outer margin collapses to zero, so this bar becomes the only
  /// thing keeping content clear of the system nav bar and needs the full
  /// inset. Interpolating between the two avoids both the peeked-state
  /// over-padding and the expanded-state overlap.
  final double bottomInsetFraction;

  /// Add-on module: answers picked in the detail page's inline addon list.
  /// ADD validates them and sends them with the dish.
  final AddonController? addonController;

  const ProductDetailBottomBar({
    super.key,
    required this.product,
    required this.selectedVariantIndex,
    this.addonController,
    this.onFirstAddToCart,
    this.bottomInsetFraction = 1,
  });

  @override
  Widget build(BuildContext context) {
    final addons = addonController;
    if (addons == null || !product.requiresAddonSheet) {
      return _buildBar(context, null);
    }
    // Add-on module: price and ADD follow the answers as they change.
    return ListenableBuilder(
      listenable: addons,
      builder: (context, _) => _buildBar(context, addons),
    );
  }

  /// Add-on module: ADD / "+" for a `has_addons` product. Shows the first
  /// unanswered rule instead of adding; otherwise adds the selected variant
  /// with its answers. Resolves to true once the dish is in the cart.
  Future<bool> _addWithAddons(
    BuildContext context,
    AddonController addons,
    Variants variant,
    double basePrice,
    String imageUrl,
  ) async {
    final problem = addons.isReady
        ? addons.validationError()
        : context.translate(LanguageLabelKeys.addonLoadFailed);
    if (problem != null) {
      AppSnackBar.show(
        context: context,
        message: problem,
        type: SnackBarType.warning,
      );
      return false;
    }
    final refusal = await addAddonProductToCart(
      context,
      productId: product.id?.toString() ?? '',
      variantId: variant.id?.toString() ?? '',
      addons: addons.selections,
      unitPrice: basePrice + addons.addonsPerDish,
      imageUrl: imageUrl,
    );
    if (refusal != null && context.mounted) {
      AppSnackBar.show(
        context: context,
        message: refusal,
        type: SnackBarType.error,
      );
    }
    return refusal == null;
  }

  Widget _buildBar(BuildContext context, AddonController? addons) {
    final variants = product.variants ?? [];
    final safeIndex = selectedVariantIndex.clamp(
      0,
      variants.isEmpty ? 0 : variants.length - 1,
    );
    final activeV = variants.isNotEmpty ? variants[safeIndex] : null;

    final rawPrice = (activeV?.price ?? 0).toDouble();
    final rawDisc = (activeV?.discountedPrice ?? 0).toDouble();
    final hasDiscount = rawDisc > 0 && rawDisc < rawPrice;
    // Add-on module: the shown price includes what the answers add.
    final addonExtra = addons?.addonsPerDish ?? 0;
    final basePrice = hasDiscount ? rawDisc : rawPrice;
    final displayPrice = basePrice + addonExtra;
    final discountPct = hasDiscount && rawPrice > 0
        ? ((rawPrice - rawDisc) / rawPrice * 100).round()
        : 0;
    final isUnlimited = (product.isUnlimitedStock ?? 0) == 1;
    final stock = activeV?.stock ?? 0;
    final outOfStock = !isUnlimited && stock <= 0;
    final isStoreClosedQuick = SettingsHiveBox.instance.isStoreClosedQuick;

    final bottomSafe = context.bottomSafePadding * bottomInsetFraction;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        bottomSafe + ThemeConstants.paddingM,
      ),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        border: Border(
          top: BorderSide(color: context.cs.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: .center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Row(
                  crossAxisAlignment: .baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AppText(
                      '${product.currency}${displayPrice.formatPrice(product.decimalPoint ?? 2)}',
                      style: context.tt.headlineSmall?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: context.cs.onSurface,
                      ),
                    ),
                    if (hasDiscount) ...[
                      AppSpacing.w6,
                      AppText(
                        '${product.currency}${(rawPrice + addonExtra).formatPrice(product.decimalPoint ?? 2)}',
                        style: context.tt.bodyMedium?.copyWith(
                          color: context.cs.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                if (hasDiscount)
                  AppText(
                    '$discountPct${AppConstants.percentSymbol}  ${context.translate(LanguageLabelKeys.off).toUpperCase()}',
                    style: context.tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.cs.primary,
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.w16,
          if (SettingsHiveBox.instance.channel == AppConstants.ecommerce &&
              product.isPincodeCheckAvailable &&
              context.watch<ServiceabilityCubit>().blocksPurchase)
            Container(
              height: 44,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingM,
              ),
              alignment: Alignment.center,
              decoration: AppDecorations.box(
                color: context.cs.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.r12,
              ),
              child: AppText(
                context.translate(LanguageLabelKeys.notDeliverable),
                style: context.tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.error,
                ),
              ),
            )
          else if (outOfStock)
            NotifyMeButton(
              key: ValueKey('notify_detail_btn_${product.id}_${activeV?.id}'),
              productVariantId: activeV?.id?.toString() ?? '',
              width: 100,
              height: 44,
              fontSize: 14,
              initiallyNotified: activeV?.isNotified ?? false,
            )
          else
            BlocBuilder<CartCubit, CartState>(
              builder: (context, cartState) {
                final variantId = activeV?.id?.toString() ?? '';
                final imageUrl =
                    activeV?.images?.coverUrl ?? product.images?.coverUrl ?? '';
                final cartButton = CartButton(
                  key: ValueKey('detail_cart_btn_${product.id}_${activeV?.id}'),
                  width: 100,
                  height: 44,
                  fontSize: 14,
                  optionsFontSize: 10,
                  optionCount: 1,
                  initialCount: cartState.countFor(variantId),
                  productId: product.id?.toString() ?? '',
                  variantId: variantId,
                  price: basePrice,
                  imageUrl: imageUrl,
                  totalAllowedQuantity: product.totalAllowedQuantity ?? 0,
                  // Add-on module: ADD sends the inline answers with the dish.
                  hasAddons: addons != null && activeV != null,
                  onAddonTap: addons == null || activeV == null
                      ? null
                      : () => _addWithAddons(
                          context,
                          addons,
                          activeV,
                          basePrice,
                          imageUrl,
                        ),
                  onFirstAdd: () => onFirstAddToCart?.call(),
                  onLastRemove: () {},
                );
                if (!isStoreClosedQuick) return cartButton;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showStoreClosedDialog(context),
                  child: Opacity(
                    opacity: 0.45,
                    child: IgnorePointer(child: cartButton),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
