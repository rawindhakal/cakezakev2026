import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/features/gifting/gift_store.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/screens/product_screen.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Shop by occasion / Gifts for / Delivery" chip rows for the home screen.
class GiftShopStrip extends StatefulWidget {
  const GiftShopStrip({super.key});

  @override
  State<GiftShopStrip> createState() => _GiftShopStripState();
}

class _GiftShopStripState extends State<GiftShopStrip> {
  final _store = GiftStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_rebuild);
    _store.loadMeta();
  }

  @override
  void dispose() {
    _store.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => mounted ? setState(() {}) : null;

  Future<void> _open(String filterKey, GiftOption o, String title) async {
    _store.activeFilter
      ..clear()
      ..[filterKey] = o.slug;
    await AppNavigator.push(
      context,
      BlocProvider(
        create: (_) => ProductCubit(),
        child: ProductScreen(title: title),
      ),
    );
    _store.activeFilter.clear();
  }

  Widget _row(String title, String key, List<GiftOption> items, String prefix) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: AppText(
              title,
              style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(items[i].name),
                side: BorderSide(color: context.cs.primary.withValues(alpha: 0.4)),
                onPressed: () => _open(key, items[i], '$prefix${items[i].name}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_store.occasions.isEmpty && _store.relationships.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _row('Shop by occasion', 'occasion', _store.occasions, ''),
          _row('Gifts for', 'relationship', _store.relationships, 'Gifts for '),
          _row('Delivery', 'delivery_type', _store.deliveryTypes, ''),
        ],
      ),
    );
  }
}
