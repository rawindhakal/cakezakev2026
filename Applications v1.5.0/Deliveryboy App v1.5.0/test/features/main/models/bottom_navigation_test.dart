import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/main/models/bottom_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_logging.dart';

/// `BottomNavItem` is a plain value holder with no parsing, so there is no
/// fromJson/toJson edge case to cover here — only that the icon paths are
/// genuinely optional, which is the branch `BottomNavBar._buildNavIcon`
/// falls back on (`SizedBox.shrink`).
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('keeps the label and both icon paths', () {
    printTestDivider('BottomNavItem keeps the label and both icon paths');
    const item = BottomNavItem(
      label: 'Home',
      activeIconPath: AssetsConstants.homeActiveIcon,
      inactiveIconPath: AssetsConstants.homeInActiveIcon,
    );

    printTestLog('label → expected: "Home", actual: "${item.label}"');
    expect(item.label, 'Home');
    printTestLog(
      'activeIconPath → expected: ${AssetsConstants.homeActiveIcon}, '
      'actual: ${item.activeIconPath}',
    );
    expect(item.activeIconPath, AssetsConstants.homeActiveIcon);
    printTestLog(
      'inactiveIconPath → expected: ${AssetsConstants.homeInActiveIcon}, '
      'actual: ${item.inactiveIconPath}',
    );
    expect(item.inactiveIconPath, AssetsConstants.homeInActiveIcon);
  });

  test('both icon paths default to null', () {
    printTestDivider('BottomNavItem both icon paths default to null');
    const item = BottomNavItem(label: 'Profile');

    printTestLog('activeIconPath → expected: null, actual: ${item.activeIconPath}');
    expect(item.activeIconPath, isNull);
    printTestLog(
      'inactiveIconPath → expected: null, actual: ${item.inactiveIconPath}',
    );
    expect(item.inactiveIconPath, isNull);
  });
}
