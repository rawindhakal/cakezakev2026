import 'package:hive_flutter/hive_flutter.dart';
import '../api/etag_interceptor.dart';
import '../api/hive_box_keys.dart';
import 'secure_key_store.dart';

class HiveService {
  HiveService._();

  static Future<void> init() async {
    await Hive.initFlutter();
    final encryptionKey = await SecureKeyStore.hiveEncryptionKey();
    await Future.wait([
      _openEncryptedAuthBox(HiveAesCipher(encryptionKey)),
      Hive.openBox(settingsBox),
      Hive.openBox(guestCartBox),
      Hive.openBox(etagCacheBox),
    ]);
    ETagInterceptor.pruneExpired();
  }

  /// Opens the encrypted auth box. If a legacy unencrypted box (or one
  /// written with a different key) exists on disk, it can't be decrypted —
  /// wipe it and recreate encrypted. The only cost is the user logging in
  /// again once.
  static Future<void> _openEncryptedAuthBox(HiveAesCipher cipher) async {
    try {
      await Hive.openBox(authBox, encryptionCipher: cipher);
    } catch (_) {
      await Hive.deleteBoxFromDisk(authBox);
      await Hive.openBox(authBox, encryptionCipher: cipher);
    }
  }
}
