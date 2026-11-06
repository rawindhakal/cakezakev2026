import 'package:customer/commons/utils/app_haptics.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/widgets/addon_section.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Add-on module: true when any variant of [variants] already sits in the
/// cart — the card's "+" then lists those lines instead of a fresh sheet.
bool hasAddonCartLines(BuildContext context, List<Variants> variants) {
  final cart = context.read<CartCubit>().state;
  return variants.any((v) => cart.countFor(v.id?.toString() ?? '') > 0);
}

/// Add-on module: "Your customisations" list, Zomato style — every cart
/// line of this dish with its answers and its own stepper, then "Add new
/// customisation". Resolves to true when that button was tapped, so the
/// caller opens the customise sheet.
class AddonCustomisationsSheet extends StatefulWidget {
  const AddonCustomisationsSheet({
    super.key,
    required this.product,
    required this.variants,
  });

  final ProductDataModel product;
  final List<Variants> variants;

  @override
  State<AddonCustomisationsSheet> createState() =>
      _AddonCustomisationsSheetState();
}

class _AddonCustomisationsSheetState extends State<AddonCustomisationsSheet> {
  /// Holds the dish's groups, used to label / price each line.
  final AddonController _addons = AddonController();

  /// Lines with a cart call in flight, by [CartState.addonLineKey].
  final Set<String> _busy = {};

  /// Cap or server refusal from the last "+", shown above the footer
  /// button — a snackbar would land behind the sheet.
  String? _error;

  ProductDataModel get product => widget.product;

  @override
  void initState() {
    super.initState();
    _addons.load(product.id?.toString() ?? '');
  }

  @override
  void dispose() {
    _addons.dispose();
    super.dispose();
  }

  double _priceOf(Variants v) {
    final raw = (v.price ?? 0).toDouble();
    final disc = (v.discountedPrice ?? 0).toDouble();
    return disc > 0 && disc < raw ? disc : raw;
  }

  String _money(double value) =>
      '${product.currency}${value.formatPrice(product.decimalPoint ?? 2)}';

  /// Same caps the card's "+" applies, for one more unit.
  String? _limitError(String variantId) {
    final cart = context.read<CartCubit>().state;
    final limit = product.totalAllowedQuantity ?? 0;
    if (limit > 0 && cart.countFor(variantId) >= limit) {
      return context.translate(LanguageLabelKeys.maxAllowedQuantityReached);
    }
    final maxCart = SettingsHiveBox.instance.maxCartItemsCount;
    if (maxCart > 0 && cart.totalItems >= maxCart) {
      return context.translate(LanguageLabelKeys.maxCartItemsReached);
    }
    return null;
  }

  Future<void> _add(Variants v, List<AddonSelection> addons, double unit) async {
    final variantId = v.id?.toString() ?? '';
    final limit = _limitError(variantId);
    if (limit != null) {
      AppHaptics.warning();
      setState(() => _error = limit);
      return;
    }
    final key = CartState.addonLineKey(variantId, addons);
    AppHaptics.tap();
    setState(() {
      _busy.add(key);
      _error = null;
    });
    final refusal = await addAddonProductToCart(
      context,
      productId: product.id?.toString() ?? '',
      variantId: variantId,
      addons: addons,
      unitPrice: unit,
      imageUrl: v.image ?? '',
    );
    if (!mounted) return;
    // Refusals (incl. "not enough stock") are a normal outcome — show them.
    setState(() {
      _busy.remove(key);
      _error = refusal;
    });
  }

  /// Takes one unit off this line — same calls as the card's "−".
  Future<void> _remove(Variants v, List<AddonSelection> addons) async {
    final variantId = v.id?.toString() ?? '';
    final cart = context.read<CartCubit>();
    AppHaptics.tap();
    if (_error != null) setState(() => _error = null);
    if (!AuthHiveBox.instance.isLoggedIn) {
      cart.removeGuestAddonLine(variantId: variantId, addons: addons);
      return;
    }
    final key = CartState.addonLineKey(variantId, addons);
    setState(() => _busy.add(key));
    final action = context.read<CartActionCubit>();
    await action.removeFromCart(
      productId: product.id?.toString() ?? '',
      productVariantId: variantId,
      qty: 1,
      addons: addons.isEmpty ? null : addons,
    );
    // A successful remove carries the full cart; "cart now empty" comes
    // back as a non-1 status, so reload instead.
    final state = action.state;
    if (state is CartActionSuccess && state.cart?.data?.cart != null) {
      cart.seedFromApi(state.cart!.data!.cart!);
    } else {
      await cart.loadFromApi();
    }
    if (mounted) setState(() => _busy.remove(key));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartCubit, CartState>(
      // The last line went — nothing left to list.
      listener: (context, cart) {
        if (!hasAddonCartLines(context, widget.variants)) {
          AppNavigator.pop(context, false);
        }
      },
      builder: (context, cart) {
        final lines = [
          for (final v in widget.variants)
            for (final addons in cart.addonLinesFor(v.id?.toString() ?? ''))
              (variant: v, addons: addons),
        ];
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.screenHeight * 0.75),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              _header(),
              Flexible(
                child: ListenableBuilder(
                  listenable: _addons,
                  builder: (context, _) => _addons.groups == null
                      ? const Padding(
                          padding: EdgeInsetsDirectional.all(
                            ThemeConstants.paddingXL,
                          ),
                          child: Center(child: LoadingWidget()),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            ThemeConstants.paddingM,
                            ThemeConstants.paddingM,
                            ThemeConstants.paddingM,
                            ThemeConstants.paddingM +
                                context.bottomSafePadding,
                          ),
                          // Same card the customise sheet uses for its groups.
                          child: AddonCard(
                            title: context.translate(
                              LanguageLabelKeys.addonYourCustomisations,
                            ),
                            children: [
                              for (var i = 0; i < lines.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    color: context.cs.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                _line(
                                  cart,
                                  lines[i].variant,
                                  lines[i].addons,
                                ),
                              ],
                              Divider(
                                height: 1,
                                color: context.cs.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              _addNew(),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Type mark + dish name, on the sheet's white top strip.
  Widget _header() {
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
      child: Text.rich(
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
    );
  }

  /// One cart line: type mark, variant, its answers, line total, stepper.
  Widget _line(CartState cart, Variants v, List<AddonSelection> addons) {
    final variantId = v.id?.toString() ?? '';
    final qty = cart.addonLineCount(variantId, addons);
    // Throwaway controller: restoring into [_addons] would notify its
    // ListenableBuilder mid-build.
    final probe = AddonController()
      ..setGroups(_addons.groups)
      ..restore(addons);
    final unit = _priceOf(v) + probe.addonsPerDish;
    final summary = probe.summary;
    probe.dispose();
    final title = widget.variants.length > 1
        ? (v.attributesText ?? v.name ?? '')
        : (product.productName ?? product.name ?? '');
    final busy = _busy.contains(CartState.addonLineKey(variantId, addons));
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingM,
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceS,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceXXS,
              children: [
                Text.rich(
                  ProductTypeIcon.nameSpan(
                    productType: product.productType,
                    name: title,
                    size: ThemeConstants.iconXS,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                if (summary.isNotEmpty)
                  AppText(
                    summary,
                    style: context.tt.bodySmall?.copyWith(
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                AppText(
                  _money(unit * qty),
                  style: context.tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          _stepper(
            qty: qty,
            enabled: !busy,
            onAdd: () => _add(v, addons, unit),
            onRemove: () => _remove(v, addons),
          ),
        ],
      ),
    );
  }

  /// Compact "− 2 +" pill for one line.
  Widget _stepper({
    required int qty,
    required bool enabled,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final color = enabled
        ? context.cs.primary
        : context.cs.primary.withValues(alpha: 0.35);
    Widget tap(String icon, VoidCallback onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 30,
        height: 32,
        child: Center(
          child: AppSvgIcon(icon, size: ThemeConstants.iconXS, color: color),
        ),
      ),
    );
    return Container(
      height: 32,
      decoration: AppDecorations.box(
        color: context.cs.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.r8,
        border: Border.all(color: context.cs.primary.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          tap(AssetsConstants.removeIcon, onRemove),
          SizedBox(
            width: 20,
            child: AppText(
              '$qty',
              textAlign: .center,
              style: context.tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.cs.primary,
              ),
            ),
          ),
          tap(AssetsConstants.addIcon, onAdd),
        ],
      ),
    );
  }

  /// Last row of the card — scrolls with the lines instead of a pinned
  /// footer, with any cap / refusal from the last "+" just above it.
  Widget _addNew() {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: ThemeConstants.paddingS,
            ),
            child: AppText(
              _error!,
              textAlign: .center,
              style: context.tt.bodySmall?.copyWith(
                color: context.cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        AppButton(
          label: context.translate(LanguageLabelKeys.addonAddNewCustomisation),
          variant: AppButtonVariant.outline,
          borderColor: Colors.transparent,
          prefixIcon: AppSvgIcon(
            AssetsConstants.addIcon,
            size: ThemeConstants.iconXS,
            color: context.cs.primary,
          ),
          height: 44,
          onPressed: () => AppNavigator.pop(context, true),
        ),
      ],
    );
  }
}
