/// Same shape as `test/fixtures/salary/salary_list.json`, inlined because an
/// integration test runs on the device, where the host's `test/fixtures`
/// directory doesn't exist. Keep the two in sync when the backend contract
/// changes.
///
/// Split into two pages (3 + 2, total 5) so a single fixture set covers both
/// the initial load and `loadMore` paging past the first page.
const Map<String, dynamic> salaryPage1Fixture = {
  'status': 1,
  'message': 'Salary payments fetched successfully',
  'total': 5,
  'data': [
    {
      'id': 701,
      'amount': 25000.00,
      'note': 'August 2026 salary',
      'paid_on': '2026-08-01',
      'currency': '₹',
    },
    {
      'id': 702,
      'amount': 25000.00,
      'note': '',
      'paid_on': '2026-07-01',
      'currency': '₹',
    },
    {
      'id': 703,
      'amount': 24500.50,
      'note': 'July 2026 salary, prorated for 2 leave days',
      'paid_on': '2026-06-01',
      'currency': '₹',
    },
  ],
};

const Map<String, dynamic> salaryPage2Fixture = {
  'status': 1,
  'message': 'Salary payments fetched successfully',
  'total': 5,
  'data': [
    {
      'id': 704,
      'amount': 24000.00,
      'note': '',
      'paid_on': '2026-05-01',
      'currency': '₹',
    },
    {
      'id': 705,
      'amount': 24000.00,
      'note': '',
      'paid_on': '2026-04-01',
      'currency': '₹',
    },
  ],
};
