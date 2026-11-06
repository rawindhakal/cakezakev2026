import 'package:customer/features/orders/models/order_model.dart';

class VariantAttributesFormatter {
  /// "Color: Red, Size: M" — null if there are no usable attribute pairs.
  static String? format(List<VariantAttributes>? attributes) {
    if (attributes == null || attributes.isEmpty) return null;
    final parts = attributes
        .where((a) => (a.name ?? '').isNotEmpty && (a.value ?? '').isNotEmpty)
        .map((a) => '${a.name}: ${a.value}')
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// "Color: Red, Size: M" → "Red" — just the first attribute's value.
  static String firstValue(String? attributesText) {
    if (attributesText == null || attributesText.isEmpty) return '';
    final firstPair = attributesText.split(',').first.trim();
    final colonIndex = firstPair.indexOf(':');
    return colonIndex == -1
        ? firstPair
        : firstPair.substring(colonIndex + 1).trim();
  }
}
