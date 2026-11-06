import 'package:customer/features/gifting/gift_store.dart';
import 'package:flutter/material.dart';

/// "Personalise this gift" field on the product page. The text travels with
/// the order as `personalization`.
class ProductPersonaliseField extends StatelessWidget {
  const ProductPersonaliseField({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextFormField(
        initialValue: GiftStore.instance.fields['personalization'],
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: '✨ Personalise this gift',
          hintText: 'Name or message to print, e.g. Happy Birthday Sita',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => GiftStore.instance.setField('personalization', v.trim()),
      ),
    );
  }
}
