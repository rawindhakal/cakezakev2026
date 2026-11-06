/// Same payload as `test/fixtures/home/dashboard_response.json`, inlined
/// because an integration test runs on the device, where the host's
/// `test/fixtures` directory doesn't exist — and bundling it as a Flutter
/// asset would ship test JSON inside the real app. Keep the two in sync when
/// the backend contract changes.
const Map<String, dynamic> dashboardResponseFixture = {
  'status': 1,
  'message': 'Success',
  'data': {
    'profile': {
      'id': 2,
      'name': 'Alex Johnson',
      'profile_url': '',
      'status': 1,
      'country': 'India',
      'currency': '₹',
      'currency_code': 'INR',
      'bonus_type': 1,
    },
    'today': {'earnings': 96.7, 'delivered': 2, 'cash': 706.5, 'orders': 2},
    'wallet': {
      'balance': 462.95,
      'total_earned': 20862.95,
      'total_debited': 400,
      'pending_withdrawal': 310,
      'total_withdrawn': 400,
      'available': 152.95,
    },
    'cash': {
      'in_hand': 16703.34,
      'total_collected': 315360.49,
      'total_deposited': 298657.15,
      'total_settled': 298657.15,
    },
    'salary': {
      'total_paid': 20000,
      'last_paid_on': '2026-08-10',
      'last_amount': 20000,
    },
    'orders': {
      'total': 31,
      'active': 6,
      'delivered': 25,
      'cancelled': 0,
      'quick': 26,
      'ecommerce': 5,
    },
    'status_breakdown': [
      {'status_id': 5, 'name': 'Out For Delivery', 'count': 5},
      {'status_id': 6, 'name': 'Delivered', 'count': 25},
      {'status_id': 11, 'name': 'Picked Up', 'count': 0},
    ],
    'returns': {
      'total': 0,
      'completed': 0,
      'pending': 0,
      'breakdown': [
        {'status_id': 5, 'name': 'Out for Pickup', 'count': 0},
        {'status_id': 6, 'name': 'Received from Customer', 'count': 0},
        {'status_id': 7, 'name': 'Return to Store', 'count': 0},
      ],
    },
    'earnings_trend': {
      'labels': ['11 Aug', '12 Aug', '13 Aug', '14 Aug', '15 Aug', '16 Aug', '17 Aug'],
      'data': [526.25, 80, 0, 80, 40, 40, 96.7],
      'trend': '7',
      'total': 862.95,
    },
    'recent_cash': [
      {
        'id': 35,
        'order_id': 187,
        'order_number': 'SB-ORD-00187',
        'type': 'COD',
        'amount': 567,
        'date': '2026-08-17 07:43:17',
      },
    ],
    'recent_withdrawals': [
      {'id': 5, 'amount': 200, 'status': 0, 'date': '2026-08-16 09:54:15'},
    ],
  },
  'total': 1,
};
