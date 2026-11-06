import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/products/widgets/addon_customisations_sheet.dart';
import 'package:customer/features/products/widgets/addon_section.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/widgets/cart_button.dart';
import 'package:customer/commons/widgets/zigzag_badge_clipper.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/features/products/models/product_detail_model.dart'
    as detail;
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductVariantSheet extends StatelessWidget {
  final ProductDataModel product;
  final List<Variants> activeVariants;
  final bool isDark;
  final void Function(Variants) onFirstAdd;
  final BuildContext parentContext;

  const ProductVariantSheet({
    super.key,
    required this.product,
    required this.activeVariants,
    required this.isDark,
    required this.onFirstAdd,
    required this.parentContext,
  });

  String _unitLabel(Variants v) => v.attributesText ?? v.name ?? '';

  @override
  Widget build(BuildContext context) {
    // Add-on module: a `has_addons` product picks one variant here and
    // answers its addon groups right below the variants, then adds once.
    if (product.requiresAddonSheet) {
      return _AddonVariantSheetBody(
        product: product,
        variants: activeVariants,
        parentContext: parentContext,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.75),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          AppSpacing.h16,
          AppText(
            product.name ?? '',
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: context.cs.onSurface,
            ),
          ),
          AppSpacing.h4,
          Flexible(
            child: SlideAnimationScope(
              builder: (context, animationController) => ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: ThemeConstants.paddingS,
                ),
                itemCount: activeVariants.length,
                separatorBuilder: (_, _) => AppSpacing.h10,
                itemBuilder: (_, i) {
                  final v = activeVariants[i];
                  final rawPrice = (v.price ?? 0).toDouble();
                  final rawDisc = (v.discountedPrice ?? 0).toDouble();
                  final hasDisc = rawDisc > 0 && rawDisc < rawPrice;
                  final displayPrice = hasDisc ? rawDisc : rawPrice;
                  final discPct = hasDisc && rawPrice > 0
                      ? ((rawPrice - rawDisc) / rawPrice * 100).round()
                      : 0;

                  final variantImage = (v.image != null && v.image!.isNotEmpty)
                      ? v.image!
                      : '';

                  return SlideAnimation(
                    position: i,
                    slideDirection: SlideDirection.fromBottom,
                    itemCount: activeVariants.length,
                    animationController: animationController,
                    child: Container(
                      padding: const EdgeInsetsDirectional.all(
                        ThemeConstants.paddingM,
                      ),
                      decoration: AppDecorations.box(
                        color: context.cs.surface,
                        borderRadius: AppRadius.r12,
                        border: Border.all(
                          color: context.cs.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (variantImage.isNotEmpty) ...[
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AppNetworkImage(
                                  url: variantImage,
                                  width: context.screenWidth * 0.18,
                                  height: context.screenWidth * 0.18,
                                  borderRadius: AppRadius.r8,
                                  fit: BoxFit.contain,
                                ),
                                if (hasDisc)
                                  PositionedDirectional(
                                    top: 0,
                                    start: 5,
                                    child: ClipPath(
                                      clipper: const ZigzagBadgeClipper(),
                                      child: Container(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              start: ThemeConstants.paddingXS,
                                              end: ThemeConstants.paddingXS,
                                              top: ThemeConstants.paddingXS,
                                              bottom: ThemeConstants.paddingXS,
                                            ),
                                        color: context.cs.primary,
                                        child: AppText(
                                          '$discPct${AppConstants.percentSymbol}\n${context.translate(LanguageLabelKeys.off).toUpperCase()}',
                                          textAlign: .center,
                                          style: context.tt.labelSmall
                                              ?.copyWith(
                                                fontSize: 8,
                                                height: 1.1,
                                                fontWeight: FontWeight.w800,
                                                color: context.cs.onPrimary,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            AppSpacing.w10,
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: .start,
                              spacing: ThemeConstants.spaceXS,
                              children: [
                                AppText(
                                  _unitLabel(v),
                                  style: context.tt.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: context.cs.onSurface,
                                  ),
                                ),
                                Row(
                                  spacing: ThemeConstants.spaceS,
                                  children: [
                                    AppText(
                                      '${product.currency}${displayPrice.formatPrice(product.decimalPoint ?? 2)}',
                                      style: context.tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: context.cs.onSurface,
                                      ),
                                    ),
                                    if (hasDisc) ...[
                                      AppText(
                                        '${product.currency}${rawPrice.formatPrice(product.decimalPoint ?? 2)}',
                                        style: context.tt.bodySmall?.copyWith(
                                          color: context.cs.onSurfaceVariant,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor:
                                              context.cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.w12,
                          CartButton(
                            key: ValueKey('sheet_btn_${v.id}'),
                            width: 80,
                            height: 36,
                            fontSize: 12,
                            optionsFontSize: 8,
                            optionCount: 1,
                            initialCount: context
                                .read<CartCubit>()
                                .state
                                .countFor(v.id?.toString() ?? ''),
                            productId: product.id?.toString() ?? '',
                            variantId: v.id?.toString() ?? '',
                            price: displayPrice,
                            imageUrl: variantImage,
                            totalAllowedQuantity:
                                product.totalAllowedQuantity ?? 0,
                            onFirstAdd: () => onFirstAdd(v),
                            onLastRemove: () {},
                            onLimitReached: () => AppNavigator.pop(context),
                            snackBarContext: parentContext,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          AppSpacing.h8,
        ],
      ),
    );
  }
}

/// Resolves to true when an add-on product was added from the sheet.
Future<bool> showProductVariantSheet({
  required BuildContext context,
  required ProductDataModel product,
  required List<Variants> variants,
  required bool isDark,
  void Function(Variants)? onFirstAdd,
}) async {
  // Add-on sheet paints its own header / footer edge to edge.
  final addonSheet = product.requiresAddonSheet;
  // Already in the cart → list its customisations first; only "Add new
  // customisation" goes on to the customise sheet.
  if (addonSheet && hasAddonCartLines(context, variants)) {
    final addNew = await showAppBottomSheet<bool>(
      context,
      backgroundColor: context.cs.surfaceContainer,
      showDragHandle: false,
      insetBottomSafeArea: false,
      navigationBarColor: context.cs.surface,
      padding: EdgeInsetsDirectional.zero,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<CartCubit>()),
          BlocProvider.value(value: context.read<CartActionCubit>()),
        ],
        child: AddonCustomisationsSheet(product: product, variants: variants),
      ),
    );
    if (addNew != true || !context.mounted) return false;
  }
  final added = await showAppBottomSheet<bool>(
    context,
    backgroundColor: context.cs.surfaceContainer,
    showDragHandle: !addonSheet,
    insetBottomSafeArea: !addonSheet,
    navigationBarColor: addonSheet ? context.cs.surface : null,
    padding: addonSheet
        ? EdgeInsetsDirectional.zero
        : const EdgeInsetsDirectional.only(
            start: ThemeConstants.paddingL,
            end: ThemeConstants.paddingL,
            top: ThemeConstants.paddingM,
          ),
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<CartCubit>()),
        BlocProvider.value(value: context.read<CartActionCubit>()),
      ],
      child: ProductVariantSheet(
        product: product,
        activeVariants: variants,
        isDark: isDark,
        onFirstAdd: onFirstAdd ?? (_) {},
        parentContext: context,
      ),
    ),
  );
  return added == true;
}

/// Add-on module: Zomato-style "Edit" on a checkout cart line — the
/// customise sheet with the line's answers and qty pre-filled, its variant
/// fixed. "Update item" swaps the line for the new answers.
Future<void> showAddonLineEditSheet({
  required BuildContext context,
  required ProductDataModel item,
  required String variantId,
  required int qty,
}) async {
  final cartVariant = item.variants?.firstOrNull;
  // Line prices already carry the add-ons; the sheet adds them back from
  // the answers. Replaced by the live variant price once the detail loads.
  final addonTotal = item.addonTotal ?? 0;
  double base(double? price) =>
      ((price ?? 0) - addonTotal).clamp(0, double.infinity).toDouble();
  final variant = Variants(
    id: int.tryParse(variantId),
    name: cartVariant?.name,
    attributesText: cartVariant?.attributesText,
    image: cartVariant?.image ?? item.images?.coverUrl,
    price: base(item.price),
    discountedPrice: (item.discountedPrice ?? 0) > 0
        ? base(item.discountedPrice)
        : 0,
    inStock: true,
  );
  // Read up front: the checkout row that opened the sheet is rebuilt away
  // once the line is swapped, while the sheet may still rebuild.
  final cartCubit = context.read<CartCubit>();
  final actionCubit = context.read<CartActionCubit>();
  await showAppBottomSheet<bool>(
    context,
    backgroundColor: context.cs.surfaceContainer,
    showDragHandle: false,
    insetBottomSafeArea: false,
    navigationBarColor: context.cs.surface,
    padding: EdgeInsetsDirectional.zero,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cartCubit),
        BlocProvider.value(value: actionCubit),
      ],
      child: _AddonVariantSheetBody(
        product: item,
        variants: [variant],
        parentContext: context,
        edit: (addons: item.addonSelections, qty: qty),
      ),
    ),
  );
}

/// Add-on module: variant sheet body for a `has_addons` product — the
/// variants as a single choice, the product's addon groups under them, and
/// one "Add item" button that sends the variant + answers to the cart.
class _AddonVariantSheetBody extends StatefulWidget {
  const _AddonVariantSheetBody({
    required this.product,
    required this.variants,
    required this.parentContext,
    this.edit,
  });

  final ProductDataModel product;
  final List<Variants> variants;
  final BuildContext parentContext;

  /// The cart line being edited (its answers as the server holds them, and
  /// its qty) — null when adding.
  final ({List<AddonSelection> addons, int qty})? edit;

  @override
  State<_AddonVariantSheetBody> createState() => _AddonVariantSheetBodyState();
}

class _AddonVariantSheetBodyState extends State<_AddonVariantSheetBody> {
  final AddonController _addons = AddonController();
  late int _selected;
  int _qty = 1;
  bool _submitting = false;
  String? _serverError;

  ProductDataModel get product => widget.product;

  @override
  void initState() {
    super.initState();
    final firstInStock = widget.variants.indexWhere((v) => !v.isOutOfStock);
    _selected = firstInStock < 0 ? 0 : firstInStock;
    // Listing cards carry only `has_addons` — fetch the groups for the
    // same coordinates cart/add will use.
    // Required groups come pre-answered so "Add item" starts enabled —
    // on the first add and on "Add new customisation" alike.
    final edit = widget.edit;
    if (edit != null) _qty = edit.qty;
    _addons.load(product.id?.toString() ?? '').then((data) {
      if (!mounted) return;
      if (edit != null) {
        _applyLiveVariant(data?.variants);
        // Answers whose option is gone are dropped here, so an edit is
        // also how a line with unavailable add-ons gets fixed.
        _addons.restore(edit.addons);
      }
      _addons.preselectRequired();
    });
    _addons.addListener(_onAddonsChanged);
  }

  /// Edit mode: the cart line only knows its price with add-ons — take the
  /// variant's own price and stock from the product detail instead.
  void _applyLiveVariant(List<detail.Variants>? liveVariants) {
    final v = _variant;
    if (v == null || liveVariants == null) return;
    final live = liveVariants.where((x) => x.id == v.id).firstOrNull;
    if (live == null) return;
    setState(() {
      v
        ..price = live.price ?? v.price
        ..discountedPrice = live.discountedPrice ?? v.discountedPrice
        ..inStock =
            live.isUnlimitedStock == 1 ||
            (live.inStock ?? (live.stock ?? 0) > 0);
    });
  }

  /// Units of this variant in the cart besides the line being edited — the
  /// caps below count the edited line's new qty instead of its old one.
  int _otherUnits(CartState cart, String variantId) =>
      cart.countFor(variantId) - (widget.edit?.qty ?? 0);

  int _otherCartItems(CartState cart) =>
      cart.totalItems - (widget.edit?.qty ?? 0);

  void _onAddonsChanged() {
    if (_serverError != null) setState(() => _serverError = null);
  }

  @override
  void dispose() {
    _addons.removeListener(_onAddonsChanged);
    _addons.dispose();
    super.dispose();
  }

  Variants? get _variant =>
      widget.variants.isEmpty ? null : widget.variants[_selected];

  double _priceOf(Variants v) {
    final raw = (v.price ?? 0).toDouble();
    final disc = (v.discountedPrice ?? 0).toDouble();
    return disc > 0 && disc < raw ? disc : raw;
  }

  String _money(double value) =>
      '${product.currency}${value.formatPrice(product.decimalPoint ?? 2)}';

  /// Same caps the plain ADD button applies, for [_qty] more units.
  String? _limitError() {
    final cart = context.read<CartCubit>().state;
    final variantId = _variant?.id?.toString() ?? '';
    final limit = product.totalAllowedQuantity ?? 0;
    if (limit > 0 && _otherUnits(cart, variantId) + _qty > limit) {
      return context.translate(LanguageLabelKeys.maxAllowedQuantityReached);
    }
    final maxCart = SettingsHiveBox.instance.maxCartItemsCount;
    if (maxCart > 0 && _otherCartItems(cart) + _qty > maxCart) {
      return context.translate(LanguageLabelKeys.maxCartItemsReached);
    }
    return null;
  }

  /// Most units the footer stepper may reach — what is left of the
  /// product's allowed quantity and the cart's item cap (null = no cap).
  int? _maxQty() {
    final cart = context.read<CartCubit>().state;
    final variantId = _variant?.id?.toString() ?? '';
    int? max;
    final limit = product.totalAllowedQuantity ?? 0;
    if (limit > 0) max = limit - _otherUnits(cart, variantId);
    final maxCart = SettingsHiveBox.instance.maxCartItemsCount;
    if (maxCart > 0) {
      final left = maxCart - _otherCartItems(cart);
      max = max == null || left < max ? left : max;
    }
    return max;
  }

  Future<void> _submit() async {
    final v = _variant;
    if (v == null) return;
    final error = _addons.validationError() ?? _limitError();
    if (error != null) {
      setState(() => _serverError = error);
      return;
    }
    setState(() {
      _submitting = true;
      _serverError = null;
    });
    final edit = widget.edit;
    final refusal = edit != null
        ? await _updateLine(v, edit.addons, edit.qty)
        : await addAddonProductToCart(
            context,
            productId: product.id?.toString() ?? '',
            variantId: v.id?.toString() ?? '',
            addons: _addons.selections,
            unitPrice: _priceOf(v) + _addons.addonsPerDish,
            imageUrl: v.image ?? '',
            count: _qty,
          );
    if (!mounted) return;
    if (refusal == null) {
      AppNavigator.pop(context, true);
      return;
    }
    // Refusals (incl. "not enough stock") are a normal outcome — show them.
    setState(() {
      _submitting = false;
      _serverError = refusal;
    });
  }

  /// Edit mode: moves the line from [oldAddons] × [oldQty] to the current
  /// answers × [_qty]. There is no cart update call, so a changed line is a
  /// remove + add — ordered so a refusal never loses the customer's line.
  /// Returns the refusal message, or null on success.
  Future<String?> _updateLine(
    Variants v,
    List<AddonSelection> oldAddons,
    int oldQty,
  ) async {
    final cart = context.read<CartCubit>();
    final variantId = v.id?.toString() ?? '';
    final newAddons = _addons.selections;
    final unit = _priceOf(v) + _addons.addonsPerDish;
    final sameLine =
        CartState.addonLineKey(variantId, newAddons) ==
        CartState.addonLineKey(variantId, oldAddons);

    Future<String?> add(List<AddonSelection> addons, int count) =>
        addAddonProductToCart(
          context,
          productId: product.id?.toString() ?? '',
          variantId: variantId,
          addons: addons,
          unitPrice: unit,
          imageUrl: v.image ?? '',
          count: count,
        );

    if (sameLine) {
      final delta = _qty - oldQty;
      if (delta > 0) return add(newAddons, delta);
      if (delta < 0) await _removeLineUnits(variantId, oldAddons, -delta);
      return null;
    }

    if (!AuthHiveBox.instance.isLoggedIn) {
      // Guest: the local cart is the cart — swap the line directly.
      cart.removeGuestAddonLine(
        variantId: variantId,
        addons: oldAddons,
        count: oldQty,
      );
      return add(newAddons, _qty);
    }

    // Add first while the caps leave room for both lines at once, so a
    // refusal (e.g. out of stock) leaves the old line untouched.
    final limit = product.totalAllowedQuantity ?? 0;
    final maxCart = SettingsHiveBox.instance.maxCartItemsCount;
    final roomForBoth =
        (limit <= 0 || cart.state.countFor(variantId) + _qty <= limit) &&
        (maxCart <= 0 || cart.state.totalItems + _qty <= maxCart);
    if (roomForBoth) {
      final refusal = await add(newAddons, _qty);
      if (refusal != null) return refusal;
      await _removeLineUnits(variantId, oldAddons, oldQty);
      return null;
    }

    // No room for both — free the old line first, and put it back if the
    // new one is refused.
    await _removeLineUnits(variantId, oldAddons, oldQty);
    if (!mounted) return null;
    final refusal = await add(newAddons, _qty);
    if (refusal != null && mounted) await add(oldAddons, oldQty);
    return refusal;
  }

  /// Takes [units] off one add-on line — cart/remove drops one unit per
  /// call — then syncs the local cart from the last response.
  Future<void> _removeLineUnits(
    String variantId,
    List<AddonSelection> addons,
    int units,
  ) async {
    final cart = context.read<CartCubit>();
    if (!AuthHiveBox.instance.isLoggedIn) {
      cart.removeGuestAddonLine(
        variantId: variantId,
        addons: addons,
        count: units,
      );
      return;
    }
    final action = context.read<CartActionCubit>();
    for (var i = 0; i < units; i++) {
      await action.removeFromCart(
        productId: product.id?.toString() ?? '',
        productVariantId: variantId,
        qty: 1,
        addons: addons,
      );
      if (action.state is CartActionError) break;
    }
    // A successful remove carries the full cart; "cart now empty" comes
    // back as a non-1 status, so reload instead.
    final state = action.state;
    if (state is CartActionSuccess && state.cart?.data?.cart != null) {
      cart.seedFromApi(state.cart!.data!.cart!);
    } else {
      await cart.loadFromApi();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.85),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          _header(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
              child: Column(
                crossAxisAlignment: .stretch,
                spacing: ThemeConstants.spaceM,
                children: [
                  // A single variant has nothing to choose — its price is
                  // already in the footer total.
                  if (widget.variants.length > 1)
                    AddonCard(
                      title: _variantTitle(),
                      children: [
                        for (var i = 0; i < widget.variants.length; i++)
                          _variantRow(i),
                      ],
                    ),
                  AddonGroupsSection(
                    controller: _addons,
                    currency: product.currency ?? '',
                    decimalPoint: product.decimalPoint ?? 2,
                  ),
                ],
              ),
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  /// Dish thumbnail + name + close, on the sheet's white top strip.
  Widget _header() {
    final productImage = product.images?.coverUrl ?? '';
    final image = productImage.isNotEmpty
        ? productImage
        : _variant?.image ?? '';
    // Selected variant's price — follows the "Select variant" choice.
    final v = _variant;
    final raw = (v?.price ?? 0).toDouble();
    final price = v == null ? 0.0 : _priceOf(v);
    final discPct = price < raw && raw > 0
        ? ((raw - price) / raw * 100).round()
        : 0;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
      ),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.top20,
        border: Border(
          bottom: BorderSide(
            color: context.cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (image.isNotEmpty) ...[
            // Same marks the plain variant sheet / product card carry:
            // discount zigzag top-start, product type bottom-end.
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppNetworkImage(
                  url: image,
                  width: 64,
                  height: 64,
                  borderRadius: AppRadius.r12,
                  fit: BoxFit.cover,
                ),
                if (discPct > 0)
                  PositionedDirectional(
                    top: 0,
                    start: 5,
                    child: ClipPath(
                      clipper: const ZigzagBadgeClipper(),
                      child: Container(
                        padding: const EdgeInsetsDirectional.all(
                          ThemeConstants.paddingXS,
                        ),
                        color: context.cs.primary,
                        child: AppText(
                          '$discPct${AppConstants.percentSymbol}\n${context.translate(LanguageLabelKeys.off).toUpperCase()}',
                          textAlign: .center,
                          style: context.tt.labelSmall?.copyWith(
                            fontSize: 8,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: context.cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.w12,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceXS,
              children: [
                Text.rich(
                  ProductTypeIcon.nameSpan(
                    productType: product.productType,
                    name: product.productName ?? product.name ?? '',
                    size: ThemeConstants.iconXS,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: context.cs.onSurface,
                  ),
                ),
                if (v != null)
                  Row(
                    spacing: ThemeConstants.spaceS,
                    children: [
                      AppText(
                        _money(price),
                        style: context.tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
                        ),
                      ),
                      if (price < raw)
                        AppText(
                          _money(raw),
                          style: context.tt.bodySmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: context.cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Attribute name(s) the variants vary by, e.g. "Size" — same title the
  /// detail page shows above its variants.
  String _variantTitle() {
    final names = <String>{
      for (final v in widget.variants)
        for (final a in v.variantAttributes ?? const [])
          if ((a.name ?? '').isNotEmpty) a.name!,
    };
    return names.isNotEmpty
        ? names.join(' / ')
        : context.translate(LanguageLabelKeys.selectVariant);
  }

  Widget _variantRow(int i) {
    final v = widget.variants[i];
    final selected = i == _selected;
    final disabled = v.isOutOfStock;
    final raw = (v.price ?? 0).toDouble();
    final price = _priceOf(v);
    final fg = disabled
        ? context.cs.onSurface.withValues(alpha: 0.38)
        : context.cs.onSurface;
    return InkWell(
      borderRadius: AppRadius.r8,
      onTap: disabled
          ? null
          : () => setState(() {
              _selected = i;
              _qty = 1;
              _serverError = null;
            }),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: ThemeConstants.paddingM,
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                v.attributesText ?? v.name ?? '',
                style: context.tt.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AppSpacing.w8,
            if (price < raw) ...[
              AppText(
                _money(raw),
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: context.cs.onSurfaceVariant,
                ),
              ),
              AppSpacing.w4,
            ],
            AppText(
              _money(price),
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            AppSpacing.w12,
            AddonSelectIndicator(
              radio: true,
              selected: selected,
              enabled: !disabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return ListenableBuilder(
      listenable: _addons,
      builder: (context, _) {
        final v = _variant;
        final ready = _addons.isReady && v != null && !v.isOutOfStock;
        // Blocked until every required group is answered — the group headers
        // already spell out the rule, so only a server refusal shows here.
        final hint = ready ? _addons.validationError() : null;
        final message = _serverError;
        final unit = (v == null ? 0.0 : _priceOf(v)) + _addons.addonsPerDish;
        final total = unit * _qty;
        return Container(
          padding: EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingL,
            ThemeConstants.paddingM,
            ThemeConstants.paddingL,
            ThemeConstants.paddingM + context.bottomSafePadding,
          ),
          decoration: AppDecorations.box(
            color: context.cs.surface,
            boxShadow: [
              BoxShadow(
                color: context.cs.shadow.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              if (message != null) ...[
                AppText(
                  message,
                  textAlign: .center,
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.h8,
              ],
              Row(
                children: [
                  _qtyStepper(enabled: ready && !_submitting),
                  AppSpacing.w12,
                  Expanded(
                    child: AppButton(
                      label: context
                          .translate(
                            widget.edit != null
                                ? LanguageLabelKeys.addonUpdateItemPrice
                                : LanguageLabelKeys.addonAddItemPrice,
                          )
                          .replaceAll('{price}', _money(total)),
                      isLoading: _submitting,
                      onPressed: !ready || _submitting || hint != null
                          ? null
                          : _submit,
                      height: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Footer "− 1 +" pill next to the add button — how many of this exact
  /// combination go in at once.
  Widget _qtyStepper({required bool enabled}) {
    final max = _maxQty();
    final canAdd = enabled && (max == null || _qty < max);
    final canRemove = enabled && _qty > 1;
    final color = context.cs.primary;
    Widget tap(String icon, bool active, int delta) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active
          ? () {
              AppHaptics.tap();
              setState(() {
                _qty += delta;
                _serverError = null;
              });
            }
          : null,
      child: SizedBox(
        width: 36,
        height: 48,
        child: Center(
          child: AppSvgIcon(
            icon,
            size: ThemeConstants.iconXS,
            color: active ? color : color.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
    return Container(
      height: 48,
      decoration: AppDecorations.box(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          tap(AssetsConstants.removeIcon, canRemove, -1),
          SizedBox(
            width: 22,
            child: AppText(
              '$_qty',
              textAlign: .center,
              style: context.tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          tap(AssetsConstants.addIcon, canAdd, 1),
        ],
      ),
    );
  }
}
