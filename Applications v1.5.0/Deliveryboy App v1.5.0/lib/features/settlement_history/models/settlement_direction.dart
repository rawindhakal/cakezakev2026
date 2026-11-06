/// Direction of a settlement entry's amount, matching the API's `type` field
/// (e.g. `credit`/`debit`) — distinct from [SettlementEntryType], which is the
/// entry's category (delivery commission, withdrawal, etc.).
enum SettlementDirection {
  credit,
  debit;

  static SettlementDirection fromValue(String? value) =>
      value?.toLowerCase() == 'credit'
      ? SettlementDirection.credit
      : SettlementDirection.debit;
}
