/// Same shapes as `test/fixtures/chat/*.json`, inlined because an integration
/// test runs on the device, where the host's `test/fixtures` directory doesn't
/// exist. Keep the two in sync when the backend contract changes.
///
/// The thread is a delivery-boy ↔ customer conversation (id 41) on order 1204:
/// two plain messages, one image attachment and one voice note, all on the
/// same day so exactly one date divider is expected.
const Map<String, dynamic> chatMessagesFixture = {
  'status': 1,
  'message': 'Messages fetched successfully',
  'data': {
    'conversation': {
      'id': 41,
      'type': 'delivery_boy_customer',
      'order_id': '1204',
      'user_id': 88,
      'delivery_boy_id': 12,
      'title': 'Order #1204',
      'last_message': 'Please leave it at the gate',
      'last_sender_type': 'user',
      'last_message_at': '2026-08-19 09:12:44',
      'last_time': '09:12 AM',
      'unread_count': 2,
    },
    'messages': [
      {
        'id': 901,
        'conversation_id': 41,
        'sender_id': 88,
        'sender_type': 'user',
        'message': 'Hi, are you nearby?',
        'attachment': null,
        'attachment_url': null,
        'created_at': '2026-08-19 09:10:02',
      },
      {
        'id': 902,
        'conversation_id': 41,
        'sender_id': 12,
        'sender_type': 'delivery_boy',
        'message': 'Five minutes away.',
        'attachment': null,
        'attachment_url': null,
        'created_at': '2026-08-19 09:10:41',
      },
      {
        'id': 903,
        'conversation_id': 41,
        'sender_id': 88,
        'sender_type': 'user',
        'message': '',
        'attachment': 'chat/41/gate-photo.jpg',
        'attachment_url':
            'https://cdn.cakezake.test/storage/chat/41/gate-photo.jpg',
        'created_at': '2026-08-19 09:11:30',
      },
      {
        'id': 904,
        'conversation_id': 41,
        'sender_id': 88,
        'sender_type': 'user',
        'message': 'Please leave it at the gate',
        'attachment': 'chat/41/voice-note.m4a',
        'attachment_url':
            'https://cdn.cakezake.test/storage/chat/41/voice-note.m4a',
        'created_at': '2026-08-19 09:12:44',
      },
    ],
  },
};

/// The older page returned for `offset > 0` — what pull-to-refresh prepends.
const Map<String, dynamic> chatOlderMessagesFixture = {
  'status': 1,
  'message': 'Messages fetched successfully',
  'data': {
    'conversation': {'id': 41},
    'messages': [
      {
        'id': 801,
        'conversation_id': 41,
        'sender_id': 88,
        'sender_type': 'user',
        'message': 'Good morning',
        'attachment': null,
        'attachment_url': null,
        'created_at': '2026-08-18 08:02:10',
      },
    ],
  },
};

/// An empty thread — nothing sent yet.
const Map<String, dynamic> chatNoMessagesFixture = {
  'status': 1,
  'message': 'Messages fetched successfully',
  'data': {
    'conversation': {'id': 41},
    'messages': <dynamic>[],
  },
};

/// `chat/send` returns an array — one row per attachment sent.
const Map<String, dynamic> chatSendMessageFixture = {
  'status': 1,
  'message': 'Message sent successfully',
  'data': [
    {
      'id': 905,
      'conversation_id': 41,
      'sender_id': 12,
      'sender_type': 'delivery_boy',
      'message': 'On my way',
      'attachment': null,
      'attachment_url': null,
      'created_at': '2026-08-19 09:13:05',
    },
  ],
};

const Map<String, dynamic> chatSendRejectedFixture = {
  'status': 0,
  'message': 'Message could not be delivered',
};

/// `chat/start_admin` — the support thread.
const Map<String, dynamic> chatStartAdminFixture = {
  'status': 1,
  'message': 'Conversation started',
  'data': {
    'id': 7,
    'type': 'admin_customer',
    'order_id': null,
    'user_id': 88,
    'delivery_boy_id': 12,
    'title': 'Support',
    'last_message': 'How can we help?',
    'last_sender_type': 'admin',
    'last_message_at': '2026-08-18 17:04:10',
    'last_time': '05:04 PM',
    'unread_count': 0,
  },
};
