/// Same shape as `test/fixtures/wallet/wallet_withdrawal_requests.json`,
/// inlined because an integration test runs on the device, where the host's
/// `test/fixtures` directory doesn't exist. Keep the two in sync when the
/// backend contract changes.
const Map<String, dynamic> walletRequestsFixture = {
  'status': 1,
  'message': 'Withdrawal requests fetched successfully',
  'total': 3,
  'data': {
    'balance': '4520.75',
    'withdraw_requests': [
      {
        'id': '501',
        'type': 'withdrawal',
        'name': 'John Doe',
        'balance': '4520.75',
        'amount': '1000.00',
        'message': 'Need cash for fuel',
        'status': '0',
        'remark': null,
        'receipt_image_url': null,
        'device_type': 'android',
        'created_at': '2026-08-18 10:15:00',
        'currency': '₹',
      },
      {
        'id': '502',
        'type': 'withdrawal',
        'name': 'John Doe',
        'balance': '3520.75',
        'amount': '800.00',
        'message': '',
        'status': '1',
        'remark': 'Approved and processed',
        'receipt_image_url': 'https://example.com/receipts/502.jpg',
        'device_type': 'android',
        'created_at': '2026-08-15 09:00:00',
        'currency': '₹',
      },
      {
        'id': '503',
        'type': 'withdrawal',
        'name': 'John Doe',
        'balance': '2720.75',
        'amount': '500.00',
        'message': 'Emergency withdrawal',
        'status': '2',
        'remark': 'Insufficient balance on record',
        'receipt_image_url': null,
        'device_type': 'ios',
        'created_at': '2026-08-10 18:30:00',
        'currency': '₹',
      },
    ],
  },
};

/// Filtered result served whenever the request carries the `status` param
/// the "apply a filter" test sets — narrows to just the pending request.
const Map<String, dynamic> walletRequestsPendingFixture = {
  'status': 1,
  'message': 'Withdrawal requests fetched successfully',
  'total': 1,
  'data': {
    'balance': '4520.75',
    'withdraw_requests': [
      {
        'id': '501',
        'type': 'withdrawal',
        'name': 'John Doe',
        'balance': '4520.75',
        'amount': '1000.00',
        'message': 'Need cash for fuel',
        'status': '0',
        'remark': null,
        'receipt_image_url': null,
        'device_type': 'android',
        'created_at': '2026-08-18 10:15:00',
        'currency': '₹',
      },
    ],
  },
};

/// Successful withdrawal submission response.
const Map<String, dynamic> withdrawalRequestSuccessFixture = {
  'status': 1,
  'message': 'Withdrawal request submitted',
};

/// Rejected withdrawal submission response (amount exceeds balance).
const Map<String, dynamic> withdrawalRequestRejectedFixture = {
  'status': 0,
  'message': 'Withdrawal amount exceeds balance',
};
