// Fixtures for `profile_flow_test.dart`. Inlined as Dart constants, not file
// reads — the test runs on the device, where the host's `test/fixtures/`
// path doesn't exist.

/// The same profile envelope `loginResponseFixture` carries, returned again
/// from `GET /edit`.
const Map<String, dynamic> profileResponseFixture = {
  'status': 1,
  'message': 'Success',
  'data': {
    'id': 2,
    'admin_id': 4,
    'country_id': 1,
    'zone_id': 2,
    'name': 'Alex Johnson',
    'profile': 'delivery_boy/profile/profile-image.webp',
    'country_code': '+91',
    'mobile': '1234567890',
    'address': 'Mumbai',
    'bonus_type': 1,
    'bonus_percentage': 10,
    'bonus_min_amount': 40,
    'bonus_max_amount': 60,
    'return_bonus_type': 1,
    'return_bonus_percentage': 10,
    'return_bonus_min_amount': 40,
    'return_bonus_max_amount': 60,
    'balance': 366.25,
    'driving_license': 'delivery_boy/driving_license/driving-license.png',
    'national_identity_card':
        'delivery_boy/national_identity_card/national-id.png',
    'dob': '1989-08-01',
    'bank_account_number': '9000323402965',
    'bank_name': 'Bank of Globe',
    'account_name': 'Alex Johnson',
    'ifsc_code': 'BANGLOB',
    'other_payment_information': '',
    'status': 1,
    'cash_received': 15996.84,
    'remark': '',
    'created_at': '2026-08-09T18:00:53.000000Z',
    'deleted_at': null,
    'pending_order_count': 6,
    'profile_url':
        'https://cakezake.com/storage/delivery_boy/profile/profile-image.webp',
    'driving_license_url':
        'https://cakezake.com/storage/delivery_boy/driving_license/driving-license.png',
    'national_identity_card_url':
        'https://cakezake.com/storage/delivery_boy/national_identity_card/national-id.png',
    'email': 'alex@gmail.com',
    'username': 'Alex Johnson',
    'access_token': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.test-access-token',
  },
};

/// Same shape as [profileResponseFixture] but with the name the edit-and-save
/// journey submits, standing in for `POST /update`'s response.
const Map<String, dynamic> updatedProfileResponseFixture = {
  'status': 1,
  'message': 'Profile updated',
  'data': {
    'id': 2,
    'admin_id': 4,
    'country_id': 1,
    'zone_id': 2,
    'name': 'Alexander Johnson',
    'profile': 'delivery_boy/profile/profile-image.webp',
    'country_code': '+91',
    'mobile': '1234567890',
    'address': 'Mumbai',
    'bonus_type': 1,
    'bonus_percentage': 10,
    'bonus_min_amount': 40,
    'bonus_max_amount': 60,
    'return_bonus_type': 1,
    'return_bonus_percentage': 10,
    'return_bonus_min_amount': 40,
    'return_bonus_max_amount': 60,
    'balance': 366.25,
    'dob': '1989-08-01',
    'bank_account_number': '9000323402965',
    'bank_name': 'Bank of Globe',
    'account_name': 'Alex Johnson',
    'ifsc_code': 'BANGLOB',
    'status': 1,
    'email': 'alex@gmail.com',
    'username': 'Alexander Johnson',
    'access_token': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.test-access-token',
  },
};

const Map<String, dynamic> countriesResponseFixture = {
  'status': 1,
  'data': [
    {
      'id': 1,
      'name': 'India',
      'is_default': 1,
      'dial_code': '+91',
      'min_mobile_length': 10,
      'max_mobile_length': 10,
    },
  ],
};

const Map<String, dynamic> zonesResponseFixture = {
  'status': 1,
  'message': 'ok',
  'data': [
    {'id': 2, 'name': 'North Zone'},
    {'id': 3, 'name': 'South Zone'},
  ],
};
