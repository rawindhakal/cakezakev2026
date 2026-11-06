/// Same shape as `test/fixtures/cash_collection/cash_collections_list.json`,
/// inlined because an integration test runs on the device, where the host's
/// `test/fixtures` directory doesn't exist. Keep the two in sync when the
/// backend contract changes.
///
/// Split into two pages (3 + 2, total 5) so a single fixture set covers both
/// the initial load and `loadMore` paging past the first page.
const Map<String, dynamic> cashCollectionsPage1Fixture = {
  'status': 1,
  'message': 'Cash collections fetched successfully',
  'total': 5,
  'data': {
    'cash_in_hand': '1245.50',
    'cash_collected': '8420.75',
    'transactions': [
      {
        'id': '301',
        'order_id': '1006',
        'transaction_id': 'TXN-000301',
        'total': '540.00',
        'final_total': '560.00',
        'payment_method': 'cod',
        'status': '6',
        'type': 'cash_collected',
        'amount': '560.00',
        'message': 'Cash collected for order #1006',
        'transaction_date': '2026-08-18 14:35:00',
        'currency': '₹',
      },
      {
        'id': '302',
        'order_id': '1007',
        'transaction_id': 'TXN-000302',
        'total': '300.00',
        'final_total': '290.00',
        'payment_method': 'wallet',
        'status': '6',
        'type': 'wallet_deduction',
        'amount': '0.00',
        'message': '',
        'transaction_date': '2026-08-18 16:05:00',
        'currency': '₹',
      },
      {
        'id': '303',
        'order_id': '1008',
        'transaction_id': 'TXN-000303',
        'total': '1200.00',
        'final_total': '1285.00',
        'payment_method': 'cod',
        'status': '6',
        'type': 'cash_collected',
        'amount': '1285.00',
        'message': 'Cash collected for order #1008',
        'transaction_date': '2026-08-17 19:25:00',
        'currency': '₹',
      },
    ],
  },
};

const Map<String, dynamic> cashCollectionsPage2Fixture = {
  'status': 1,
  'message': 'Cash collections fetched successfully',
  'total': 5,
  'data': {
    'cash_in_hand': '1245.50',
    'cash_collected': '8420.75',
    'transactions': [
      {
        'id': '304',
        'order_id': '1009',
        'transaction_id': 'TXN-000304',
        'total': '400.00',
        'final_total': '400.00',
        'payment_method': 'cod',
        'status': '6',
        'type': 'cash_collected',
        'amount': '400.00',
        'message': 'Cash collected for order #1009',
        'transaction_date': '2026-08-16 12:00:00',
        'currency': '₹',
      },
      {
        'id': '305',
        'order_id': '1010',
        'transaction_id': 'TXN-000305',
        'total': '150.00',
        'final_total': '150.00',
        'payment_method': 'cod',
        'status': '6',
        'type': 'cash_collected',
        'amount': '150.00',
        'message': 'Cash collected for order #1010',
        'transaction_date': '2026-08-15 09:30:00',
        'currency': '₹',
      },
    ],
  },
};

/// A filtered result — the fake adapter serves this whenever the request
/// carries the `search`/date-range params the "apply a filter" test sets, so
/// the assertion is on the narrowed list actually rendering, not just on the
/// query the app sent.
const Map<String, dynamic> cashCollectionsFilteredFixture = {
  'status': 1,
  'message': 'Cash collections fetched successfully',
  'total': 1,
  'data': {
    'cash_in_hand': '1245.50',
    'cash_collected': '8420.75',
    'transactions': [
      {
        'id': '301',
        'order_id': '1006',
        'transaction_id': 'TXN-000301',
        'total': '540.00',
        'final_total': '560.00',
        'payment_method': 'cod',
        'status': '6',
        'type': 'cash_collected',
        'amount': '560.00',
        'message': 'Cash collected for order #1006',
        'transaction_date': '2026-08-18 14:35:00',
        'currency': '₹',
      },
    ],
  },
};
