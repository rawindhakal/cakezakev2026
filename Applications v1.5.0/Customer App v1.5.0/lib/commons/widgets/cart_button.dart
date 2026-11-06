import 'dart:async';
import 'package:customer/commons/utils/app_log.dart';
import 'package:customer/core/constants/theme_constants.dart';

import '../../commons/widgets/app_text.dart';

import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';
import 'package:customer/core/localization/language_label_key.dart';

class CartButton extends StatefulWidget {
  final double width;
  final double height;
  final double fontSize;
  final double optionsFontSize;
  final int optionCount;
  final int initialCount;
  final String productId;
  final String variantId;
  final double price;
  final String imageUrl;
  final int totalAllowedQuantity;
  final VoidCallback onFirstAdd;
  final VoidCallback onLastRemove;
  final VoidCallback? onLimitReached;
  final BuildContext? snackBarContext;

  // Add-on module: when [hasAddons] is true, "add" / "+" don't add
  // straight to the cart — they call [onAddonTap], which collects the
  // dish's answers (variant sheet from listings, the inline addon section
  // on product detail) and resolves to true once the dish was added.
  final bool hasAddons;
  final Future<bool> Function()? onAddonTap;

  const CartButton({
    super.key,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.optionsFontSize,
    required this.optionCount,
    required this.initialCount,
    required this.productId,
    required this.variantId,
    required this.price,
    required this.onFirstAdd,
    required this.onLastRemove,
    this.totalAllowedQuantity = 0,
    this.imageUrl = '',
    this.onLimitReached,
    this.snackBarContext,
    this.hasAddons = false,
    this.onAddonTap,
  });

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton>
    with SingleTickerProviderStateMixin {
  late int _count;
  bool _increasing = true;

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  // Debounced server sync (logged-in only): coalesce a tap burst into one call.
  Timer? _syncDebounce;
  int? _baseQty; // server-confirmed qty captured at the start of a burst
  CartActionCubit? _actionCubit;
  // True while this button's own sync request is in flight — gates the
  // BlocListener below so only the button that actually fired the request
  // reacts to its result (the cubit is a single shared instance).
  bool _awaitingAction = false;
  // Base qty captured for the in-flight request, kept so a failed sync can
  // roll the optimistic local qty back to what the server still holds.
  int? _pendingRevertBase;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
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
  void didUpdateWidget(CartButton old) {
    super.didUpdateWidget(old);
    if (old.initialCount != widget.initialCount) {
      setState(() => _count = widget.initialCount);
    }
  }

  @override
  void dispose() {
    // Persist any pending change before the widget goes away.
    if (_syncDebounce?.isActive ?? false) {
      _syncDebounce!.cancel();
      _actionCubit?.unregisterPendingFlush(_flushSync);
      _flushSync();
    }
    _scaleCtrl.dispose();
    super.dispose();
  }

  /// [baseQty] = the qty before this tap; captured once per burst.
  void _scheduleSync(int baseQty) {
    if (!AuthHiveBox.instance.isLoggedIn) return;
    _actionCubit = context.read<CartActionCubit>();
    _baseQty ??= baseQty;
    if (_syncDebounce == null) {
      // First tap of this burst — register so a channel switch can force
      // this request out under the current channel before its timer fires.
      _actionCubit!.registerPendingFlush(_flushSync);
    }
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), () {
      _actionCubit?.unregisterPendingFlush(_flushSync);
      _flushSync();
    });
  }

  /// Sends the net change accumulated during the burst as one request.
  Future<void> _flushSync() async {
    _syncDebounce?.cancel();
    _syncDebounce = null;
    final base = _baseQty;
    final action = _actionCubit;
    _baseQty = null;
    if (base == null || action == null) return;
    final delta = _count - base;
    if (delta == 0) return;
    _awaitingAction = true;
    _pendingRevertBase = base;
    if (delta > 0) {
      await action.addToCart(
        productId: widget.productId,
        productVariantId: widget.variantId,
        qty: _count,
      );
    } else {
      await action.removeFromCart(
        productId: widget.productId,
        productVariantId: widget.variantId,
        qty: -delta,
      );
    }
  }

  /// Per-product and whole-cart quantity caps. Shows the warning and
  /// returns false when another unit can't be added.
  bool _canAddOneMore() {
    final limit = widget.totalAllowedQuantity;
    if (limit > 0 && _count >= limit) {
      widget.onLimitReached?.call();
      final snackContext = widget.snackBarContext ?? context;
      AppSnackBar.show(
        context: snackContext,
        message: context.translate(LanguageLabelKeys.maxAllowedQuantityReached),
        type: SnackBarType.warning,
      );
      return false;
    }

    final maxCartItems = SettingsHiveBox.instance.maxCartItemsCount;
    final totalItems = context.read<CartCubit>().state.totalItems;
    if (maxCartItems > 0 && totalItems >= maxCartItems) {
      widget.onLimitReached?.call();
      final snackContext = widget.snackBarContext ?? context;
      AppSnackBar.show(
        context: snackContext,
        message: context.translate(LanguageLabelKeys.maxCartItemsReached),
        type: SnackBarType.warning,
      );
      return false;
    }
    return true;
  }

  /// Add-on module: "add" / "+" on an add-on product. The caller's
  /// [CartButton.onAddonTap] collects the answers and adds the dish.
  Future<void> _onAddonAdd() async {
    final onAddonTap = widget.onAddonTap;
    final wasZero = _count == 0;
    // Once in the cart, "+" opens the customisations list, which can also
    // lower a line — its own "+" applies the caps.
    if (onAddonTap == null || (wasZero && !_canAddOneMore())) return;
    AppHaptics.tap();
    final added = await onAddonTap();
    if (!mounted || !added) return;
    _increasing = true;
    _scaleCtrl.forward(from: 0.0);
    if (wasZero) widget.onFirstAdd();
  }

  /// Add-on module: "−" on an add-on product. With a single line in the
  /// cart it's unambiguous, so remove one unit of that line (passing its
  /// answers so the right line is hit). With several customised lines the
  /// customer picks which one — in the caller's customisations list when
  /// [CartButton.onAddonTap] opens one, else in the cart.
  Future<void> _decrementAddon() async {
    final cart = context.read<CartCubit>();
    final lines = cart.state.addonLinesFor(widget.variantId);
    final onAddonTap = widget.onAddonTap;
    if (lines.length > 1 && onAddonTap != null) {
      AppHaptics.tap();
      await onAddonTap();
      return;
    }
    if (lines.length != 1) {
      AppSnackBar.show(
        context: widget.snackBarContext ?? context,
        message: context.translate(LanguageLabelKeys.addonRemoveFromCart),
        type: SnackBarType.info,
      );
      return;
    }
    if (_count == 1) widget.onLastRemove();
    AppHaptics.tap();
    setState(() {
      _increasing = false;
      _count--;
    });
    _scaleCtrl.forward(from: 0.0);
    if (!AuthHiveBox.instance.isLoggedIn) {
      // Guest: the line lives in the local cart.
      cart.removeGuestAddonLine(
        variantId: widget.variantId,
        addons: lines.first,
      );
      return;
    }
    final action = context.read<CartActionCubit>();
    await action.removeFromCart(
      productId: widget.productId,
      productVariantId: widget.variantId,
      qty: 1,
      addons: lines.first.isEmpty ? null : lines.first,
    );
    // Resync from the server either way: a successful remove carries the
    // full cart, and a "cart now empty" non-1 status is not a real failure.
    final state = action.state;
    if (state is CartActionSuccess && state.cart?.data?.cart != null) {
      cart.seedFromApi(state.cart!.data!.cart!);
    } else {
      await cart.loadFromApi();
    }
  }

  void _increment() {
    if (!_canAddOneMore()) return;

    final wasZero = _count == 0;
    final baseQty = _count;
    AppHaptics.tap();
    setState(() {
      _increasing = true;
      _count++;
    });
    _scaleCtrl.forward(from: 0.0);
    if (wasZero) widget.onFirstAdd();
    try {
      context.read<CartCubit>().add(
        widget.variantId,
        widget.price,
        imageUrl: widget.imageUrl,
      );
    } catch (e, s) {
      logDebug('CartButton add (local): $e\n$s');
    }
    _scheduleSync(baseQty);
  }

  void _decrement() {
    if (_count <= 0) return;
    if (widget.hasAddons) {
      _decrementAddon();
      return;
    }
    final willBeZero = _count == 1;
    final baseQty = _count;
    AppHaptics.tap();
    setState(() {
      _increasing = false;
      _count--;
    });
    _scaleCtrl.forward(from: 0.0);
    if (willBeZero) widget.onLastRemove();
    try {
      context.read<CartCubit>().remove(widget.variantId, widget.price);
    } catch (e, s) {
      logDebug('CartButton remove (local): $e\n$s');
    }
    _scheduleSync(baseQty);
  }

  @override
  Widget build(BuildContext context) {
    final isStepper = _count > 0;

    return BlocListener<CartActionCubit, CartActionState>(
      listenWhen: (_, curr) =>
          _awaitingAction &&
          (curr is CartActionSuccess || curr is CartActionError),
      listener: (ctx, state) {
        _awaitingAction = false;
        final revertBase = _pendingRevertBase;
        _pendingRevertBase = null;
        if (state is CartActionError) {
          // Only roll back if no newer tap burst has started since this
          // request was fired — otherwise we'd stomp on a fresher change.
          // Skip entirely for fromRemove: some backends respond with a
          // non-1 status when a remove call empties the cart, which isn't
          // a real failure — rolling back would re-add the item we just
          // correctly removed.
          if (!state.fromRemove &&
              revertBase != null &&
              _syncDebounce == null &&
              _baseQty == null &&
              _count != revertBase) {
            setState(() => _count = revertBase);
            try {
              ctx.read<CartCubit>().setQuantity(
                widget.variantId,
                widget.price,
                revertBase,
                imageUrl: widget.imageUrl,
              );
            } catch (e, s) {
              logDebug('CartButton revert (local): $e\n$s');
            }
          }
          if (!state.fromRemove) {
            final snackContext = widget.snackBarContext ?? ctx;
            AppSnackBar.show(
              context: snackContext,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        }
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          width: widget.width,
          height: widget.height,
          decoration: AppDecorations.cartControl(
            cs: context.cs,
            filled: isStepper,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.r10,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) {
                final isCounterChild = child.key == const ValueKey('counter');
                final slideBegin = Offset(0, isCounterChild ? 1.0 : -1.0);
                return SlideTransition(
                  position: Tween<Offset>(begin: slideBegin, end: Offset.zero)
                      .animate(
                        CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: isStepper ? _stepperView() : _addView(),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle? get _addLabelStyle => context.tt.headlineMedium?.copyWith(
    color: context.cs.primary,
    fontSize: widget.fontSize,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  );

  Widget _addLabelText() => AppText(
    context.translate(LanguageLabelKeys.add).toUpperCase(),
    style: _addLabelStyle,
  );

  Widget _addView() {
    final fg = context.cs.onPrimary;
    final opts = widget.optionCount;

    if (opts > 1) {
      return GestureDetector(
        key: const ValueKey('add'),
        onTap: widget.onFirstAdd,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Expanded(child: Center(child: _addLabelText())),
            Container(
              color: context.cs.primary,
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: ThemeConstants.paddingXS,
              ),
              child: Center(
                child: AppText(
                  '$opts ${context.translate(LanguageLabelKeys.options)}',
                  style: context.tt.labelLarge?.copyWith(
                    fontSize: widget.optionsFontSize,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      key: const ValueKey('add'),
      // Add-on module: an add-on product asks its questions first.
      onTap: widget.hasAddons ? _onAddonAdd : _increment,
      behavior: HitTestBehavior.opaque,
      child: Center(child: _addLabelText()),
    );
  }

  // Every gift is a single item: no quantity. Once in the cart the control
  // is a one-tap "Remove".
  Widget _stepperView() {
    final fg = context.cs.onPrimary;
    final isMulti = widget.optionCount > 1;
    return GestureDetector(
      key: const ValueKey('counter'),
      onTap: isMulti ? widget.onFirstAdd : _decrement,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AppText(
          context.translate(LanguageLabelKeys.remove).toUpperCase(),
          style: context.tt.headlineMedium?.copyWith(
            color: fg,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
