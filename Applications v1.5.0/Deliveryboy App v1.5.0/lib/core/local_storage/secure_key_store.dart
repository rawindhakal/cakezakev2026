import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/hive_box_keys.dart';

/// Bridges OS-level secure storage with Hive encryption.
///
/// The 256-bit AES key used to encrypt the auth box is generated once and
/// persisted in the platform keystore (iOS Keychain / Android Keystore-backed
/// EncryptedSharedPreferences) — never in a plain Hive box. This keeps the
/// stored auth token unreadable at rest on the device.
class SecureKeyStore {
  SecureKeyStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Returns the Hive AES encryption key, generating and persisting a new one
  /// on first launch.
  static Future<List<int>> hiveEncryptionKey() async {
    final existing = await _storage.read(key: kHiveEncryptionKey);
    if (existing != null) {
      return base64Url.decode(existing);
    }

    final key = Hive.generateSecureKey();
    await _storage.write(key: kHiveEncryptionKey, value: base64UrlEncode(key));
    return key;
  }
}
