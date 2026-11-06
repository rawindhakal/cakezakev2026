import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

/// Opens a plain (unencrypted) temp-dir-backed box for tests that exercise
/// `AuthHiveBox`/`SettingsHiveBox`/`GuestCartHiveBox`, which read via
/// `Hive.box(name)` — the real app opens some of these encrypted, but the
/// cipher only matters for the real device keystore-backed key, not for what
/// a test needs to verify (that the right keys/values get written and read
/// back).
class HiveTestHelper {
  HiveTestHelper._();

  static Directory? _tempDir;

  static Future<void> setUp(String boxName) => setUpBoxes([boxName]);

  static Future<void> tearDown(String boxName) => tearDownBoxes([boxName]);

  /// Opens several boxes against a *single* shared temp dir.
  ///
  /// Calling [setUp] twice does not work: each call creates its own temp dir
  /// and re-points `Hive.init` at it, overwriting [_tempDir]. The first
  /// [tearDown] then deletes that directory out from under the box opened by
  /// the earlier call, and the second tear-down dies with a
  /// `PathNotFoundException` on the missing `.lock` file. Any test needing
  /// more than one box (e.g. anything touching both `AuthHiveBox` and
  /// `SettingsHiveBox`) must use these list-taking variants instead.
  static Future<void> setUpBoxes(List<String> boxNames) async {
    _tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(_tempDir!.path);
    for (final boxName in boxNames) {
      await Hive.openBox(boxName);
    }
  }

  static Future<void> tearDownBoxes(List<String> boxNames) async {
    for (final boxName in boxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
        await Hive.deleteBoxFromDisk(boxName);
      }
    }
    if (_tempDir != null && _tempDir!.existsSync()) {
      _tempDir!.deleteSync(recursive: true);
    }
    _tempDir = null;
  }
}
