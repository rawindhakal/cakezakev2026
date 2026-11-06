import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

/// Opens a plain (unencrypted) temp-dir-backed `auth` box for tests that
/// exercise `AuthHiveBox`, which reads via `Hive.box(authBox)` — the real
/// app opens it encrypted, but the cipher only matters for the real device
/// keystore-backed key, not for what a test needs to verify (that the right
/// keys/values get written and read back).
class HiveTestHelper {
  HiveTestHelper._();

  static Directory? _tempDir;

  static Future<void> setUp(String boxName) async {
    _tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(_tempDir!.path);
    await Hive.openBox(boxName);
  }

  static Future<void> tearDown(String boxName) async {
    await Hive.box(boxName).close();
    await Hive.deleteBoxFromDisk(boxName);
    if (_tempDir != null && _tempDir!.existsSync()) {
      _tempDir!.deleteSync(recursive: true);
    }
  }
}
