/// Same shape as `test/fixtures/blog/*.json`, inlined because an integration
/// test runs on the device, where the host's `test/fixtures` directory
/// doesn't exist. Keep the two in sync when the backend contract changes.
///
/// `status` here must stay a numeric `1`, unlike every other field on this
/// envelope — see `faq_fixtures.dart` for why (`ApiClient._handleResponse`
/// checks `data['status'] == 1` before any model parsing runs).
///
/// `BlogCubit.computeHasMore` is page-length based
/// (`response.data.length >= AppConfig.pageLimit`, not total-based like the
/// base class default), so page 1 must return exactly `AppConfig.pageLimit`
/// (10) items for `hasMore` to flip true and the scroll-to-load-more flow to
/// trigger — a short page 1 would make the pagination test a false negative
/// (no next-page request, not because paging is broken, but because the
/// fixture never claimed there was a next page).
Map<String, dynamic> _blog({
  required String id,
  required String title,
  String categoryId = '2',
  String categoryName = 'Delivery',
}) => {
  'id': id,
  'title': title,
  'slug': title.toLowerCase().replaceAll(' ', '-'),
  'category_id': categoryId,
  'short_description': 'Short teaser for $title.',
  'description': '<p>Full body for $title.</p>',
  'image_url': 'https://example.com/blogs/$id.jpg',
  'category': {'id': categoryId, 'name': categoryName},
  'views_count': '${10 * int.parse(id)}',
  'created_at': '2026-08-01 10:00:00',
  'read_time': '3',
  'lang': 'en',
};

final Map<String, dynamic> blogPage1Fixture = {
  'status': 1,
  'message': 'Blogs found',
  'total': '11',
  'data': List.generate(
    10,
    (i) => _blog(id: '${i + 1}', title: 'Blog Post ${i + 1}'),
  ),
};

final Map<String, dynamic> blogPage2Fixture = {
  'status': 1,
  'message': 'Blogs found',
  'total': '11',
  'data': [_blog(id: '11', title: 'Blog Post 11')],
};

/// Filtered result for `category_id=2` (only the Delivery-tagged blog) —
/// short on purpose, so `hasMore` is false and the filtered list is easy to
/// assert on by exact count.
final Map<String, dynamic> blogFilteredByDeliveryFixture = {
  'status': 1,
  'message': 'Blogs found',
  'total': '1',
  'data': [_blog(id: '1', title: 'Blog Post 1')],
};

const Map<String, dynamic> blogCategoriesFixture = {
  'status': 1,
  'message': 'Blog categories found',
  'data': [
    {'id': '2', 'name': 'Delivery', 'active_blogs_count': '1'},
    {'id': '3', 'name': 'Groceries', 'active_blogs_count': '10'},
  ],
};
