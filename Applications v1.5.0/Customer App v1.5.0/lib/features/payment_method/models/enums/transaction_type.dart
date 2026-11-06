/// Value sent to the backend as `type` on the transaction APIs
/// (`initiate_transaction` / `add_transaction`) — tells the backend whether the
/// payment settles an order or tops up the user's wallet.
enum TransactionType {
  order('order'),
  wallet('wallet');

  const TransactionType(this.apiValue);

  /// Value sent to backend as `type`.
  final String apiValue;

  /// Reads the value back out of an untyped params/extra map. Returns null for
  /// anything the backend doesn't define.
  static TransactionType? fromRaw(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase();
    for (final type in TransactionType.values) {
      if (type.apiValue == normalized) return type;
    }
    return null;
  }
}
