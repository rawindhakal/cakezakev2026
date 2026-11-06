/// Same shape as `test/fixtures/notifications/notification_settings.json`,
/// inlined because an integration test runs on the device, where the host's
/// `test/fixtures` directory doesn't exist. Keep the two in sync when the
/// backend contract changes.
///
/// 3 categories: "Order Updates" (every channel populated on both events),
/// "Payments" (sms n/a on both events), "Promotions" (push false, sms n/a
/// on both events) — exercises the null-channel "hide the tile" and
/// "hide the whole category" paths on the sms tab.
const Map<String, dynamic> notificationSettingsFixture = {
  'status': 1,
  'message': 'Notification preferences fetched successfully',
  'total': 3,
  'data': [
    {
      'category': 'Order Updates',
      'events': [
        {
          'key': 'order_placed',
          'label': 'Order Placed',
          'channels': {'mail': true, 'push': true, 'sms': false},
        },
        {
          'key': 'order_delivered',
          'label': 'Order Delivered',
          'channels': {'mail': true, 'push': true, 'sms': true},
        },
      ],
    },
    {
      'category': 'Payments',
      'events': [
        {
          'key': 'payment_received',
          'label': 'Payment Received',
          'channels': {'mail': true, 'push': true, 'sms': null},
        },
        {
          'key': 'payout_processed',
          'label': 'Payout Processed',
          'channels': {'mail': false, 'push': true, 'sms': null},
        },
      ],
    },
    {
      'category': 'Promotions',
      'events': [
        {
          'key': 'promo_offer',
          'label': 'Promo Offer',
          'channels': {'mail': true, 'push': false, 'sms': null},
        },
        {
          'key': 'promo_flash_sale',
          'label': 'Flash Sale Alert',
          'channels': {'mail': true, 'push': false, 'sms': null},
        },
      ],
    },
  ],
};

const Map<String, dynamic> notificationSaveSuccessFixture = {
  'status': 1,
  'message': 'Settings saved',
};

const Map<String, dynamic> notificationSaveRejectedFixture = {
  'status': 0,
  'message': 'Could not save preferences',
};
