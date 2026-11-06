/// Settlement/fund-transfer entry type, matching the API's `entry_type` filter values.
enum SettlementEntryType {
  all(''),
  deliveryCommission('delivery_commission'),
  returnCommission('return_commission'),
  withdrawal('withdrawal'),
  cashDepositCash('cash_deposit_cash'),
  cashDepositWallet('cash_deposit_wallet');

  const SettlementEntryType(this.value);

  final String value;

  static SettlementEntryType fromValue(String value) =>
      SettlementEntryType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => SettlementEntryType.all,
      );
}
