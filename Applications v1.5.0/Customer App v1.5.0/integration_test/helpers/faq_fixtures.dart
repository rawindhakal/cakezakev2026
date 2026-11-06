/// Same shape as `test/fixtures/faq/faq_list.json`, inlined because an
/// integration test runs on the device, where the host's `test/fixtures`
/// directory doesn't exist. Keep the two in sync when the backend contract
/// changes.
///
/// `status` here must stay a numeric `1`, unlike every other field on this
/// envelope: `ApiClient._handleResponse` checks `data['status'] == 1` (an int
/// literal) to decide success vs. throwing, before any of this ever reaches
/// `FaqResponse.fromJson` — which itself only ever sees `'1'` as a string, via
/// `?.toString()`, and would tolerate either. A JSON-encoded string `"1"`
/// fails that `== 1` check silently and turns every response into an error
/// surfaced with this envelope's own `message`, not a thrown exception —
/// exactly what happened here before this was caught.
///
/// Split into two pages (2 + 1, total 3) so a single fixture set covers both
/// the initial load and `fetchMore` paging past the first page.
const Map<String, dynamic> faqPage1Fixture = {
  'status': 1,
  'message': 'Faqs found',
  'total': '3',
  'data': [
    {
      'id': '1',
      'question': 'How do I track my order?',
      'answer':
          'Open Orders from your profile and tap any order to see its live status.',
      'lang': 'en',
    },
    {
      'id': '2',
      'question': 'What payment methods are supported?',
      'answer':
          'Cards, UPI, wallet balance, and cash on delivery where available.',
      'lang': 'en',
    },
  ],
};

const Map<String, dynamic> faqPage2Fixture = {
  'status': 1,
  'message': 'Faqs found',
  'total': '3',
  'data': [
    {
      'id': '3',
      'question': 'How do I request a refund?',
      'answer':
          "Go to the order's detail screen and tap Request Refund within the return window.",
      'lang': 'en',
    },
  ],
};
