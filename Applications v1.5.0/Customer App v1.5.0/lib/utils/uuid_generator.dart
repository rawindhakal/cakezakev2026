import 'dart:math';

/// Generates a random UUID v4 string (e.g. "f47ac10b-58cc-4372-a567-
/// 0e02b2c3d479") without pulling in the `uuid` package — used as the
/// `request_token` idempotency key for the spin wheel's spin API.
String generateUuidV4() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));

  // Per RFC 4122: version 4 in the high nibble of byte 6, variant bits
  // (10xxxxxx) in byte 8.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
