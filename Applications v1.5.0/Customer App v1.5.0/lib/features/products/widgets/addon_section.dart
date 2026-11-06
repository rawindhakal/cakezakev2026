import 'package:customer/commons/utils/app_haptics.dart';
import 'package:customer/commons/utils/app_log.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/commons/widgets/product_type_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/features/products/models/product_detail_model.dart'
    show ProductDetailDataModel;
import 'package:customer/features/products/repositories/product_repository.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Add-on module: holds an add-on product's `addon_groups` and the
/// customer's answers. Shared by the product detail page (inline, under the
/// variants) and the variant sheet (under its variant list), so both apply
/// the same PDF rules: radio = exactly one, `max_select` counts different
/// options (0 = no limit), `max_qty` caps a stepper, `free_limit` covers
/// the most expensive picks first.
class AddonController extends ChangeNotifier {
  List<AddonGroup>? _groups;
  bool _loadFailed = false;

  /// groupId → (optionId → qty per unit of the dish).
  final Map<int, Map<int, int>> _picked = {};

  /// Null while loading.
  List<AddonGroup>? get groups => _groups;
  bool get loadFailed => _loadFailed;
  bool get isReady => _groups != null && !_loadFailed;

  /// Uses groups the caller already has (product detail). Answers to
  /// options that no longer exist are dropped.
  void setGroups(List<AddonGroup>? groups) {
    _groups = _usable(groups ?? const []);
    _loadFailed = false;
    final validIds = {
      for (final g in _groups!)
        for (final o in g.options!) o.id,
    };
    for (final picks in _picked.values) {
      picks.removeWhere((id, _) => !validIds.contains(id));
    }
    _picked.removeWhere((_, picks) => picks.isEmpty);
    notifyListeners();
  }

  /// Fetches groups from `product_by_id` with the same coordinates cart/add
  /// uses, so an option can't vanish between the two steps (listing cards
  /// only carry `has_addons`, not the groups). Resolves to the fetched
  /// detail (null on failure) for callers that also need its variants.
  Future<ProductDetailDataModel?> load(String productId) async {
    _groups = null;
    _loadFailed = false;
    notifyListeners();
    try {
      final detail = await ProductRepository().getProductDetail(
        productId: productId,
      );
      setGroups(detail.data?.addonGroups);
      return detail.data;
    } catch (e) {
      logDebug('AddonController load failed: $e');
      _loadFailed = true;
      notifyListeners();
      return null;
    }
  }

  /// Groups whose options were all dropped by the store never reach the
  /// client, but guard anyway so an empty group can't block "required".
  List<AddonGroup> _usable(List<AddonGroup> groups) => groups
      .where((g) => g.id != null && (g.options?.isNotEmpty ?? false))
      .toList();

  int qtyOf(AddonGroup g, AddonOption o) => _picked[g.id]?[o.id] ?? 0;

  int distinctPicked(AddonGroup g) => _picked[g.id]?.length ?? 0;

  /// `max_select` counts *different* options; 0 = no limit.
  bool isMaxReached(AddonGroup g) =>
      g.hasMaxSelect && distinctPicked(g) >= (g.maxSelect ?? 0);

  void setQty(AddonGroup g, AddonOption o, int qty) {
    final gid = g.id;
    final oid = o.id;
    if (gid == null || oid == null) return;
    AppHaptics.tap();
    final map = _picked.putIfAbsent(gid, () => {});
    if (g.isRadio) {
      // A radio group is always exactly one pick, whatever the numbers say.
      map.clear();
      if (qty > 0) map[oid] = 1;
    } else if (qty <= 0) {
      map.remove(oid);
    } else {
      map[oid] = qty.clamp(1, o.maxQty ?? 1);
    }
    if (map.isEmpty) _picked.remove(gid);
    notifyListeners();
  }

  void toggle(AddonGroup g, AddonOption o) {
    final selected = qtyOf(g, o) > 0;
    if (g.isRadio) {
      // Tapping the chosen answer of an optional radio clears it; a
      // required one stays answered.
      if (selected && !g.required) {
        setQty(g, o, 0);
      } else if (!selected) {
        setQty(g, o, 1);
      }
      return;
    }
    if (selected) {
      setQty(g, o, 0);
    } else if (!isMaxReached(g)) {
      setQty(g, o, 1);
    }
  }

  /// The client-side checks from the spec, worded like the server's
  /// refusals. Returns the first problem, or null when the answers are valid.
  String? validationError() {
    final t = LocalizationService.instance;
    for (final g in _groups ?? const <AddonGroup>[]) {
      final distinct = distinctPicked(g);
      final name = g.name ?? '';
      if (g.required && distinct == 0) {
        return t
            .translate(LanguageLabelKeys.addonChooseOptionFor)
            .replaceAll('{group}', name);
      }
      final min = g.isRadio ? 0 : (g.minSelect ?? 0);
      if ((g.required || distinct > 0) && distinct < min) {
        return t
            .translate(LanguageLabelKeys.addonChooseAtLeast)
            .replaceAll('{count}', '$min')
            .replaceAll('{group}', name);
      }
    }
    return null;
  }

  /// `{id, qty}` list for cart/add — option ids only, never group ids.
  List<AddonSelection> get selections => [
    for (final groupPicks in _picked.values)
      for (final e in groupPicks.entries)
        AddonSelection(id: e.key, qty: e.value),
  ];

  /// optionId → how many of its picked units the group's `free_limit`
  /// covers. The allowance goes to the most expensive picks first (never
  /// the first-listed or first-chosen), matching the server.
  Map<int, int> freeUnits(AddonGroup g) {
    final limit = g.freeLimit ?? 0;
    if (limit <= 0) return const {};
    final units = <AddonOption>[
      for (final o in g.options ?? const <AddonOption>[])
        for (var i = 0; i < qtyOf(g, o); i++) o,
    ]..sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
    final free = <int, int>{};
    for (final o in units.take(limit)) {
      final id = o.id;
      if (id != null) free[id] = (free[id] ?? 0) + 1;
    }
    return free;
  }

  /// Display estimate of what the answers add per dish. The cart
  /// response's `line_price` / `is_free` stay the source of truth.
  double get addonsPerDish {
    var total = 0.0;
    for (final g in _groups ?? const <AddonGroup>[]) {
      final free = freeUnits(g);
      for (final o in g.options ?? const <AddonOption>[]) {
        total += (qtyOf(g, o) - (free[o.id] ?? 0)) * (o.price ?? 0);
      }
    }
    return total;
  }

  /// Drops every answer in [g] (the card's "Clear").
  void clearGroup(AddonGroup g) {
    if (_picked.remove(g.id) == null) return;
    AppHaptics.tap();
    notifyListeners();
  }

  void reset() {
    _picked.clear();
    notifyListeners();
  }

  /// Answers every unanswered required group with its first options (no
  /// haptics): one for a radio, `min_select` (at least 1, within
  /// `max_select`) for a checkbox — so a first add isn't blocked.
  void preselectRequired() {
    var changed = false;
    for (final g in _groups ?? const <AddonGroup>[]) {
      final gid = g.id;
      if (gid == null || !g.required || distinctPicked(g) > 0) continue;
      final min = g.minSelect ?? 0;
      var count = g.isRadio || min < 1 ? 1 : min;
      if (g.hasMaxSelect && count > g.maxSelect!) count = g.maxSelect!;
      final picks = <int, int>{
        for (final o
            in g.options!
                .where(
                  (o) => o.id != null && o.inStock != 0 && (o.maxQty ?? 1) > 0,
                )
                .take(count))
          o.id!: 1,
      };
      if (picks.isEmpty) continue;
      _picked[gid] = picks;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Re-applies a cart line's answers (no haptics), e.g. to price or label
  /// that line. Ids not in [groups] are dropped.
  void restore(Iterable<AddonSelection> selections) {
    _picked.clear();
    for (final s in selections) {
      for (final g in _groups ?? const <AddonGroup>[]) {
        final gid = g.id;
        if (gid == null) continue;
        if (g.options?.any((o) => o.id == s.id) ?? false) {
          _picked.putIfAbsent(gid, () => {})[s.id] = s.qty;
          break;
        }
      }
    }
    notifyListeners();
  }

  /// "2 × Olives, Cheese burst" for the current answers, in group order.
  String get summary => [
    for (final g in _groups ?? const <AddonGroup>[])
      for (final o in g.options ?? const <AddonOption>[])
        if (qtyOf(g, o) > 0)
          qtyOf(g, o) > 1 ? '${qtyOf(g, o)} × ${o.name ?? ''}' : o.name ?? '',
  ].join(', ');
}

/// Add-on module: adds [count] units of a dish with [addons] to the cart.
/// Logged in → cart/add with the line's resulting qty (an existing line
/// with the same answers + [count], else a new line of [count]). Guest → the local cart
/// line, priced later by `guest_cart` (`items`). Returns the refusal
/// message (e.g. not enough stock — a normal outcome), or null on success.
Future<String?> addAddonProductToCart(
  BuildContext context, {
  required String productId,
  required String variantId,
  required List<AddonSelection> addons,
  required double unitPrice,
  String imageUrl = '',
  int count = 1,
}) async {
  final cart = context.read<CartCubit>();
  if (!AuthHiveBox.instance.isLoggedIn) {
    for (var i = 0; i < count; i++) {
      cart.addGuestAddonLine(
        productId: productId,
        variantId: variantId,
        price: unitPrice,
        addons: addons,
        imageUrl: imageUrl,
      );
    }
    return null;
  }
  final action = context.read<CartActionCubit>();
  final existing = cart.state.addonLineCount(variantId, addons);
  await action.addToCart(
    productId: productId,
    productVariantId: variantId,
    qty: existing + count,
    addons: addons,
  );
  final state = action.state;
  if (state is CartActionSuccess) {
    final items = state.cart?.data?.cart;
    if (items != null) cart.seedFromApi(items);
    return null;
  }
  return state is CartActionError
      ? state.message
      : LocalizationService.instance.translate(
          LanguageLabelKeys.somethingWentWrong,
        );
}

/// Add-on module: renders an add-on product's addon groups in order —
/// name, backend `selection_text`, radio / checkbox / stepper per option,
/// strike-through on offers, "Free" for free picks, disabled once
/// `max_select` is reached. Lays out as a plain Column so it sits inside the
/// host's own scroll view (detail page, variant sheet).
class AddonGroupsSection extends StatelessWidget {
  const AddonGroupsSection({
    super.key,
    required this.controller,
    required this.currency,
    required this.decimalPoint,
  });

  final AddonController controller;
  final String currency;
  final int decimalPoint;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loadFailed) {
          return _message(
            context,
            context.translate(LanguageLabelKeys.addonLoadFailed),
          );
        }
        final groups = controller.groups;
        if (groups == null) {
          return const Padding(
            padding: EdgeInsetsDirectional.all(ThemeConstants.paddingL),
            child: Center(child: LoadingWidget()),
          );
        }
        // Empty addon_groups = nothing to ask; the dish adds as-is.
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: .stretch,
          spacing: ThemeConstants.spaceM,
          children: [for (final g in groups) _groupCard(context, g)],
        );
      },
    );
  }

  Widget _message(BuildContext context, String text) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      vertical: ThemeConstants.paddingM,
    ),
    child: AppText(
      text,
      textAlign: .center,
      style: context.tt.bodySmall?.copyWith(color: context.cs.error),
    ),
  );

  String _money(double value) => '$currency${value.formatPrice(decimalPoint)}';

  Widget _groupCard(BuildContext context, AddonGroup g) {
    final free = controller.freeUnits(g);
    return AddonCard(
      title: g.name ?? '',
      // Backend-generated rules sentence — never composed locally.
      subtitle: g.selectionText,
      satisfied: controller.distinctPicked(g) > 0,
      onClear: () => controller.clearGroup(g),
      children: [
        for (final o in g.options ?? const <AddonOption>[])
          _optionRow(context, g, o, free[o.id] ?? 0),
      ],
    );
  }

  Widget _optionRow(
    BuildContext context,
    AddonGroup g,
    AddonOption o,
    int freeUnits,
  ) {
    final qty = controller.qtyOf(g, o);
    final selected = qty > 0;
    final disabled = !selected && !g.isRadio && controller.isMaxReached(g);
    // Group's max_qty_per_option above 1 → stepper (bounded by the option's
    // own max_qty, which may be lower for a linked product); else a tick.
    final useStepper = !g.isRadio && (g.maxQtyPerOption ?? 1) > 1;
    final fg = disabled
        ? context.cs.onSurface.withValues(alpha: 0.38)
        : context.cs.onSurface;

    return InkWell(
      borderRadius: AppRadius.r8,
      onTap: disabled || (useStepper && selected)
          ? null
          : () => controller.toggle(g, o),
      child: Padding(
        // The 48dp thumbnail already gives the row its height, so image
        // rows take less padding than text-only ones.
        padding: EdgeInsetsDirectional.symmetric(
          vertical: o.hasImage ? 6 : ThemeConstants.paddingM,
        ),
        child: Row(
          children: [
            if (o.hasImage) ...[
              Opacity(
                opacity: disabled ? 0.38 : 1,
                child: _optionImage(context, o),
              ),
              AppSpacing.w12,
            ],
            // Same veg / non-veg / … mark the product cards use, inline
            // before the name. With an image it sits on the image instead.
            Expanded(
              child: Text.rich(
                ProductTypeIcon.nameSpan(
                  productType: o.hasImage ? null : o.productType,
                  name: o.name ?? '',
                  size: ThemeConstants.iconXS,
                  opacity: disabled ? 0.38 : 1,
                ),
                style: context.tt.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            // A price-0 option (radio, tick or stepper) shows no price at
            // all — "Free" there is noise. Only free_limit-covered paid
            // picks still say "Free".
            if (!o.isFree) ...[
              AppSpacing.w8,
              _priceLabel(context, o, fg, freeUnits: freeUnits, qty: qty),
            ],
            AppSpacing.w12,
            if (useStepper)
              _stepper(context, g, o, qty, disabled)
            else
              AddonSelectIndicator(
                radio: g.isRadio,
                selected: selected,
                enabled: !disabled,
              ),
          ],
        ),
      ),
    );
  }

  /// Option thumbnail: whole image fitted (never cropped) in a bordered
  /// white tile, with the product-type mark pinned to its top-start corner.
  Widget _optionImage(BuildContext context, AddonOption o) {
    const size = 48.0;
    return Container(
      width: size,
      height: size,
      decoration: AppDecorations.box(
        color: Colors.white,
        borderRadius: AppRadius.r8,
        border: Border.all(color: context.cs.outlineVariant, width: 0.8),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(
                ThemeConstants.paddingXS,
              ),
              child: AppNetworkImage(
                url: o.image!,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorIconSize: ThemeConstants.iconXS,
              ),
            ),
          ),
          if ((o.productType ?? 0) != 0)
            PositionedDirectional(
              top: 3,
              start: 3,
              child: ProductTypeIcon(productType: o.productType, size: 11),
            ),
        ],
      ),
    );
  }

  Widget _priceLabel(
    BuildContext context,
    AddonOption o,
    Color fg, {
    required int freeUnits,
    required int qty,
  }) {
    // Admin-free option (price 0), or every picked unit covered by the
    // group's free_limit → shown at 0 as "Free".
    if (o.isFree || (qty > 0 && freeUnits >= qty)) {
      return AppText(
        context.translate(LanguageLabelKeys.free),
        style: context.tt.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.cs.primary,
        ),
      );
    }
    return Row(
      mainAxisSize: .min,
      spacing: ThemeConstants.spaceXS,
      children: [
        // original_price above price = an offer → strike-through.
        if (o.hasOffer)
          AppText(
            _money(o.originalPrice ?? 0),
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
              decorationColor: context.cs.onSurfaceVariant,
            ),
          ),
        AppText(
          '+${_money(o.price ?? 0)}',
          style: context.tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    );
  }

  Widget _stepper(
    BuildContext context,
    AddonGroup g,
    AddonOption o,
    int qty,
    bool disabled,
  ) {
    final max = o.maxQty ?? 1;
    final color = disabled
        ? context.cs.primary.withValues(alpha: 0.35)
        : context.cs.primary;
    Widget tap(String icon, VoidCallback? onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingXS),
        child: AppSvgIcon(
          icon,
          size: ThemeConstants.iconXS,
          color: onTap == null ? color.withValues(alpha: 0.35) : color,
        ),
      ),
    );
    // Nothing picked yet → a single "Add" pill; the first tap puts in 1
    // and the stepper takes over from there.
    if (qty == 0) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : () => controller.setQty(g, o, 1),
        child: Container(
          height: 30,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingM,
          ),
          alignment: Alignment.center,
          decoration: AppDecorations.box(
            border: Border.all(color: color),
            borderRadius: AppRadius.r8,
          ),
          child: AppText(
            context.translate(LanguageLabelKeys.add),
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
    }
    return Container(
      height: 30,
      decoration: AppDecorations.box(
        border: Border.all(color: color),
        borderRadius: AppRadius.r8,
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          tap(
            AssetsConstants.removeIcon,
            qty > 0 ? () => controller.setQty(g, o, qty - 1) : null,
          ),
          SizedBox(
            width: 18,
            child: Center(
              child: AppText(
                '$qty',
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          // Capped at the option's max_qty (per unit of the dish); a new
          // option is also blocked once max_select different ones are in.
          tap(
            AssetsConstants.addIcon,
            (qty < max && !disabled)
                ? () => controller.setQty(g, o, qty + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Add-on module: one white question card (addon group or the variant
/// choice) — bold title, rules line under it (it already says
/// "Required"), a "Clear" once something is picked, a dashed rule, then the
/// option rows.
class AddonCard extends StatelessWidget {
  const AddonCard({
    super.key,
    required this.title,
    this.subtitle,
    this.satisfied = false,
    this.onClear,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final bool satisfied;

  /// Shown as "Clear" once [satisfied]; null = nothing to clear (variant).
  final VoidCallback? onClear;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        ThemeConstants.paddingXS,
      ),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        borderRadius: AppRadius.r16,
        border: Border.all(
          color: context.cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            crossAxisAlignment: .start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceXXS,
                  children: [
                    AppText(
                      title,
                      style: context.tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.cs.onSurface,
                      ),
                    ),
                    if ((subtitle ?? '').isNotEmpty)
                      AppText(
                        subtitle!,
                        style: context.tt.bodySmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              AppSpacing.w8,
              _trailing(context),
            ],
          ),
          AppSpacing.h10,
          CustomPaint(
            size: const Size.fromHeight(1),
            painter: _DashPainter(context.cs.outlineVariant),
          ),
          AppSpacing.h2,
          ...children,
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    final Widget child;
    if (satisfied && onClear != null) {
      child = GestureDetector(
        key: const ValueKey('clear'),
        behavior: HitTestBehavior.opaque,
        onTap: onClear,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingXS,
            vertical: 3,
          ),
          child: AppText(
            context.translate(LanguageLabelKeys.clear),
            style: context.tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.primary,
            ),
          ),
        ),
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('none'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

/// Add-on module: radio / checkbox mark at the end of an option row.
class AddonSelectIndicator extends StatelessWidget {
  const AddonSelectIndicator({
    super.key,
    required this.radio,
    required this.selected,
    this.enabled = true,
  });

  final bool radio;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = context.cs.primary;
    final idle = enabled
        ? context.cs.onSurfaceVariant.withValues(alpha: 0.6)
        : context.cs.onSurface.withValues(alpha: 0.2);
    const size = 20.0;
    const duration = Duration(milliseconds: 180);
    if (radio) {
      return AnimatedContainer(
        duration: duration,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: AppDecorations.box(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? active : idle, width: 1.5),
        ),
        // Scale, not size: easeOutBack overshoots below 0 on the way out,
        // and a negative width/height throws.
        child: AnimatedScale(
          duration: duration,
          curve: selected ? Curves.easeOutBack : Curves.easeIn,
          scale: selected ? 1 : 0,
          child: Container(
            width: 10,
            height: 10,
            decoration: AppDecorations.box(
              color: active,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return AnimatedContainer(
      duration: duration,
      width: size,
      height: size,
      decoration: AppDecorations.box(
        color: selected ? active : Colors.transparent,
        borderRadius: AppRadius.r4,
        border: Border.all(color: selected ? active : idle, width: 1.5),
      ),
      child: AnimatedOpacity(
        duration: duration,
        opacity: selected ? 1 : 0,
        child: Icon(Icons.check_rounded, size: 14, color: context.cs.onPrimary),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0;
    const gap = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
