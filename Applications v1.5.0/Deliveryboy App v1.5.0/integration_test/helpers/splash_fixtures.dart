// Fixtures for the splash/main end-to-end flows.
//
// Dart constants rather than file reads: the test runs on the device, where
// the host's `test/fixtures/` path doesn't exist, and adding it to
// `pubspec.yaml` assets would ship test JSON inside the real app.

/// `/settings` with the delivery-boy app mode switched **off** — the normal
/// path through splash.
const Map<String, dynamic> settingsResponseFixture = {
  'status': 1,
  'message': 'Settings fetched successfully',
  'data': {
    'app_name': 'CakeZake Delivery',
    'app_mode_delivery_boy': '0',
    'app_mode_delivery_boy_remark': '',
    'is_version_system_on': '0',
    'ios_is_version_system_on': '0',
    'current_version': '1.0.0',
    'ios_current_version': '1.0.0',
    'currency': '₹',
    'map_provider': 'google',
  },
};

/// `/settings` with the delivery-boy app under maintenance.
const Map<String, dynamic> maintenanceSettingsResponseFixture = {
  'status': 1,
  'message': 'Settings fetched successfully',
  'data': {
    'app_name': 'CakeZake Delivery',
    'app_mode_delivery_boy': '1',
    'app_mode_delivery_boy_remark': 'Scheduled upgrade — back at 6pm IST',
    'is_version_system_on': '0',
    'ios_is_version_system_on': '0',
  },
};

/// `/system_languages` — the list call (no `id` parameter) and the per-language
/// detail call are the same endpoint, so the responder branches on `id`.
const Map<String, dynamic> systemLanguagesListFixture = {
  'status': 1,
  'message': 'Languages fetched successfully',
  'total': 1,
  'data': [
    {
      'id': '1',
      'name': 'English',
      'code': 'en',
      'type': 'ltr',
      'system_type': '2',
      'is_default': '1',
      'display_name': 'English',
    },
  ],
};

/// `/system_languages?id=1` — one language, translations included.
const Map<String, dynamic> systemLanguageDetailFixture = {
  'status': 1,
  'message': 'Language fetched successfully',
  'data': {
    'id': '1',
    'name': 'English',
    'code': 'en',
    'type': 'ltr',
    'system_type': '2',
    'is_default': '1',
    'json_data': {'home': 'Home', 'my_delivery': 'My Delivery'},
  },
};

/// An empty `/dashboard` payload — the main-screen flow is about the tabs, not
/// about what any one of them renders.
const Map<String, dynamic> emptyDashboardFixture = {
  'status': 1,
  'message': 'Dashboard fetched successfully',
  'data': <String, dynamic>{},
};

/// An empty paginated list, reused for every list endpoint the tabs hit.
const Map<String, dynamic> emptyListFixture = {
  'status': 1,
  'message': 'No data found',
  'total': 0,
  'data': <dynamic>[],
};
