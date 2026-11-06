// Fixtures for the orders flow, inlined because an integration test runs on
// the device, where the host's `test/fixtures` directory doesn't exist. Keep
// these in sync with `test/fixtures/orders/*.json` when the backend
// contract changes.

/// Single quick order at active_status 5 (Out For Delivery) — mid-flow, so
/// the status bar offers exactly one next step (6, Delivered).
const Map<String, dynamic> ordersListFixture = {
  'status': 1,
  'message': 'success',
  'total': 1,
  'data': [
    {
      'id': 512,
      'order_id': 512,
      'order_number': 'SB-ORD-00512',
      'active_status': 5,
      'status_name': 'Out For Delivery',
      'order_status_name': 'Out For Delivery',
      'payment_method': 'cod',
      'final_total': 420,
      'currency': '₹',
      'date': '2026-08-18T10:00:00.000000Z',
    },
  ],
};

Map<String, dynamic> orderDetailFixture({required int activeStatus}) => {
  'status': 1,
  'message': 'Success',
  'data': {
    'order': {
      'id': 512,
      'order_id': 512,
      'order_number': 'SB-ORD-00512',
      'active_status': activeStatus,
      'status_name': activeStatus == 6 ? 'Delivered' : 'Out For Delivery',
      'order_status_name': activeStatus == 6 ? 'Delivered' : 'Out For Delivery',
      'currency': '₹',
      'payment_method': 'cod',
      'final_total': 420,
      'branch_info': {'branch_name': 'Bhuj Store'},
      'address': {'name': 'Ravi Kumar', 'address': '221B Baker Street', 'mobile': '9876543210'},
    },
    'order_items': [],
    'timeline': [],
  },
};

const Map<String, dynamic> orderStatusesFixture = {
  'status': 1,
  'message': 'success',
  'data': [
    {'id': 10, 'status': 'Ready for Pickup', 'status_name': 'Ready for Pickup'},
    {'id': 11, 'status': 'Picked Up', 'status_name': 'Picked Up'},
    {'id': 5, 'status': 'Out For Delivery', 'status_name': 'Out For Delivery'},
    {'id': 6, 'status': 'Delivered', 'status_name': 'Delivered'},
  ],
  'return_statuses': [],
};

const Map<String, dynamic> updateStatusFixture = {
  'status': 1,
  'message': 'Order status updated',
};

const Map<String, dynamic> emptyOrdersListFixture = {
  'status': 1,
  'message': 'success',
  'total': 0,
  'data': [],
};
