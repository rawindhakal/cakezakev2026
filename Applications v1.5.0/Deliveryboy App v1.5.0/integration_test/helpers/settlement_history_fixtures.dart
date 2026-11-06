/// Same shape as `test/fixtures/settlement_history/settlement_history_list.json`,
/// inlined because an integration test runs on the device, where the host's
/// `test/fixtures` directory doesn't exist. Keep the two in sync when the
/// backend contract changes.
///
/// Split into two pages (3 + 2, total 5) so a single fixture set covers both
/// the initial load and `loadMore` paging past the first page.
const Map<String, dynamic> settlementHistoryPage1Fixture = {
  'status': 1,
  'message': 'Settlement history fetched successfully',
  'total': 5,
  'data': [
    {
      'id': '901',
      'delivery_boy_id': 42,
      'entry_type': 'delivery_commission',
      'type': 'credit',
      'amount': '150.75',
      'opening_balance': '1200.00',
      'closing_balance': '1350.75',
      'currency': '₹',
      'message': 'Commission for order #1006',
      'created_at': '2026-08-17 12:00:00',
    },
    {
      'id': '902',
      'delivery_boy_id': 42,
      'entry_type': 'withdrawal',
      'type': 'debit',
      'amount': 500,
      'opening_balance': 1350.75,
      'closing_balance': 850.75,
      'currency': '₹',
      'message': 'Withdrawal to bank account',
      'created_at': '2026-08-16 12:00:00',
    },
    {
      'id': '903',
      'delivery_boy_id': 42,
      'entry_type': 'cash_deposit_wallet',
      'type': 'debit',
      'amount': 320.5,
      'opening_balance': 850.75,
      'closing_balance': 530.25,
      'currency': '₹',
      'message': null,
      'created_at': '2026-08-15 12:00:00',
    },
  ],
};

const Map<String, dynamic> settlementHistoryPage2Fixture = {
  'status': 1,
  'message': 'Settlement history fetched successfully',
  'total': 5,
  'data': [
    {
      'id': '904',
      'delivery_boy_id': 42,
      'entry_type': 'return_commission',
      'type': 'credit',
      'amount': 40,
      'opening_balance': 530.25,
      'closing_balance': 570.25,
      'currency': '₹',
      'message': 'Return commission for order #1002',
      'created_at': '2026-08-14 12:00:00',
    },
    {
      'id': '905',
      'delivery_boy_id': 42,
      'entry_type': 'cash_deposit_cash',
      'type': 'debit',
      'amount': 70.25,
      'opening_balance': 570.25,
      'closing_balance': 500,
      'currency': '₹',
      'message': '',
      'created_at': '2026-08-13 12:00:00',
    },
  ],
};

/// Single-entry page served when a search or entry-type filter is applied, so
/// a filtered fetch is visibly different from the unfiltered one.
const Map<String, dynamic> settlementHistoryFilteredFixture = {
  'status': 1,
  'message': 'Settlement history fetched successfully',
  'total': 1,
  'data': [
    {
      'id': '902',
      'delivery_boy_id': 42,
      'entry_type': 'withdrawal',
      'type': 'debit',
      'amount': 500,
      'opening_balance': 1350.75,
      'closing_balance': 850.75,
      'currency': '₹',
      'message': 'Withdrawal to bank account',
      'created_at': '2026-08-16 12:00:00',
    },
  ],
};
