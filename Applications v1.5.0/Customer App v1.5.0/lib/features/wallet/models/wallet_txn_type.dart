enum WalletTxnType {
  credit('credit'),
  debit('debit');

  final String apiValue;
  const WalletTxnType(this.apiValue);

  static WalletTxnType? fromApiValue(String? value) {
    if (value == null) return null;
    for (final t in WalletTxnType.values) {
      if (t.apiValue == value.toLowerCase()) return t;
    }
    return null;
  }
}
