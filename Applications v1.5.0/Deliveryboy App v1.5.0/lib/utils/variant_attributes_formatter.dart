// Formatting helpers for product variant attributes shared across order cards.
//
// The order, order-detail and ecommerce models each declare their own
// `VariantAttributes` type, but all expose the same nullable `name`/`value`
// string fields — so these helpers accept the entries dynamically to avoid
// duplicating the identical formatting logic in every card.

/// "Color: Red, Size: M" — joins usable name/value pairs; returns null when
/// there are no attributes with both a non-empty name and value.
String? formatVariantPairs(List<dynamic>? attributes) {
  if (attributes == null || attributes.isEmpty) return null;
  final parts = attributes
      .where(
        (a) =>
            ((a.name ?? '') as String).isNotEmpty &&
            ((a.value ?? '') as String).isNotEmpty,
      )
      .map((a) => '${a.name}: ${a.value}')
      .toList();
  return parts.isEmpty ? null : parts.join(', ');
}

/// "Red, M" — joins the non-empty variant values only; empty string when none.
String formatVariantValues(List<dynamic>? attributes) =>
    attributes
        ?.map((a) => (a.value ?? '') as String)
        .where((v) => v.isNotEmpty)
        .join(', ') ??
    '';
