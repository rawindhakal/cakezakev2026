/// Real-shaped API payloads for `auth_flow_test.dart`, inlined (rather than
/// read from `test/fixtures/auth/`) because an integration test runs on the
/// device/simulator, where the host's `test/` directory doesn't exist — same
/// reasoning as `faq_fixtures.dart`/`blog_fixtures.dart`.
///
/// `status` stays a numeric `1` on every envelope here, not `'1'`:
/// `ApiClient._handleResponse` checks the raw JSON body's `status` field with
/// `== 1` (an int literal) before any model parsing ever runs — a
/// JSON-encoded string `"1"` fails that check silently and turns the whole
/// response into a generic error, the exact gotcha `faq_fixtures.dart`
/// documents. `AuthModel.status` itself also happens to be a bare `int` (via
/// `parseInt(...) ?? 0`), unlike faq/blog's stringified envelope `status` —
/// two independent reasons this app's auth fixtures need a numeric status,
/// not just one.
library;

/// Only the fields `SignInScreen`/`_initModeIfNeeded` actually branch on are
/// set to something other than their zero-value default — every other
/// `AppSettingsData` field defaults to `''`/`null` via its own `fromJson`,
/// which the screen never reads on the sign-in path.
const Map<String, dynamic> settingsFixture = {
  'status': 1,
  'message': 'Settings found',
  'data': {
    'email_login': '1',
    'phone_login': '0',
    'google_login': '0',
    'apple_login': '0',
    'firebase_authentication': '0',
    'custom_sms_gateway_otp_based': '0',
    'phone_auth_password': '0',
  },
};

/// One default-flagged country — enough for `CountriesCubit`'s
/// `CountriesLoaded` state and `findDefaultCountry` to resolve without a
/// network round trip mattering to this test (`SignInScreen` only reads it
/// to prefill the phone form, which the email-only fixture above never
/// mounts).
const Map<String, dynamic> countriesFixture = {
  'status': 1,
  'message': 'Countries found',
  'total': '1',
  'data': [
    {
      'id': 1,
      'name': 'United States',
      'code': 'US',
      'dial_code': '+1',
      'is_default': 1,
      'min_mobile_length': 10,
      'max_mobile_length': 10,
    },
  ],
};

/// A successful `/login` response — `AuthModelData.access_token` non-empty
/// is what `SignInCubit`'s success branch checks before persisting the
/// session and emitting `SignInLoaded`.
const Map<String, dynamic> loginSuccessFixture = {
  'status': 1,
  'message': 'Login successful',
  'status_code': 'LOGIN_SUCCESS',
  'data': {
    'id': 42,
    'name': 'Jordan Blake',
    'email': 'jordan.blake@example.com',
    'country_code': '',
    'mobile': '',
    'profile': '',
    'balance': 0,
    'referral_code': 'JORDAN42',
    'type': 'email',
    'access_token': 'integration-test-access-token',
  },
};

/// A rejected `/login` response — no `access_token`, `status` still `1`
/// (the envelope succeeded, the credentials didn't) with a `message` the
/// screen surfaces verbatim via `AppSnackBar`.
const Map<String, dynamic> loginInvalidCredentialsFixture = {
  'status': 0,
  'message': 'Invalid email or password',
  'status_code': 'INVALID_CREDENTIALS',
  'data': null,
};
