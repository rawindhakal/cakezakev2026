import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/guest_cart_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/cart/cubit/guest_cart_sync_cubit.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GuestCartSyncHelper {
  GuestCartSyncHelper._();

  /// One channel's guest basket as bulk-add lines. Plain units go first
  /// and add-on lines last: the server stops at the first refused line with
  /// the earlier ones already added, so a refused add-on line (option gone /
  /// out of stock) can't keep the plain items out of the cart.
  static List<BulkCartItem> _basket(String channel) {
    // Add-on module: a guest's saved add-on lines for [channel].
    final addonLines = GuestCartHiveBox.instance
        .loadAddonLines(channel)
        .map(AddonCartLine.fromJson)
        .whereType<AddonCartLine>()
        .toList();
    final plain = <BulkCartItem>[];
    for (final e in GuestCartHiveBox.instance.loadEntries(channel).values) {
      final id = e['variantId'] as String? ?? '';
      if (id.isEmpty) continue;
      // Units that belong to add-on lines are sent with their answers
      // below, not bare — a required group refuses a bare add.
      final addonQty = addonLines
          .where((l) => l.variantId == id)
          .fold<int>(0, (s, l) => s + l.qty);
      final qty = (e['quantity'] as int? ?? 0) - addonQty;
      if (qty <= 0) continue;
      plain.add(BulkCartItem(variantId: id, qty: qty));
    }
    return [...plain, ...addonLines.map((l) => l.toBulkItem())];
  }

  static Future<void> syncAndNavigate(BuildContext context) async {
    final quick = _basket(AppConstants.quick);
    final ecommerce = _basket(AppConstants.ecommerce);

    if (quick.isNotEmpty || ecommerce.isNotEmpty) {
      final syncCubit = context.read<GuestCartSyncCubit>();
      try {
        await syncCubit.bulkAddItems(
          quickItems: quick,
          ecommerceItems: ecommerce,
        );
      } catch (_) {}
      if (!context.mounted) return;
      // bulkAddItems swallows failures into GuestCartSyncError rather than
      // throwing, so the try/catch above can't detect them — check the
      // resulting state instead. Only wipe the local guest cart once the
      // server confirms the merge; clearing on a failed sync would silently
      // lose the user's cart items.
      //
      // Add-on module: add-on lines go last, so a refusal that reached
      // them has already merged every plain line. That refused line (option
      // gone / out of stock) would be refused again on retry, and keeping the
      // guest cart would re-add the merged lines twice next time — so it
      // doesn't hold back clearing.
      final state = syncCubit.state;
      final hasAddonLines = [
        ...quick,
        ...ecommerce,
      ].any((i) => i.hasAddons);
      if (state is GuestCartSyncSuccess ||
          (state is GuestCartSyncError && state.refused && hasAddonLines)) {
        context.read<CartCubit>().clearAllGuestData();
      }
      context.read<CartCubit>().loadFromApi();
    }

    if (!context.mounted) return;
    AppNavigator.pushNamedAndRemoveUntil(
      context,
      SettingsHiveBox.instance.hasLocation
          ? RouteNames.main
          : RouteNames.locationRequired,
    );
  }
}
