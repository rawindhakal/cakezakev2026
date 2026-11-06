import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/main/models/bottom_navigation.dart';
import 'package:deliveryboy/features/main/widgets/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// The bar's own active-tab indicator. Scoped to [BottomNavBar] because
/// MaterialApp's page route contributes a `PositionedDirectional` of its own.
final _indicatorFinder = find.descendant(
  of: find.byType(BottomNavBar),
  matching: find.byType(PositionedDirectional),
);

/// `BottomNavBar` is a pure presentational widget — index in, tap index out —
/// so it is tested standalone rather than through `MainScreen` (which mounts
/// all four tab screens at once).
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  const items = [
    BottomNavItem(
      label: 'Home',
      activeIconPath: AssetsConstants.homeActiveIcon,
      inactiveIconPath: AssetsConstants.homeInActiveIcon,
    ),
    BottomNavItem(
      label: 'My Delivery',
      activeIconPath: AssetsConstants.orderActiveIcon,
      inactiveIconPath: AssetsConstants.orderInActiveIcon,
    ),
    BottomNavItem(
      label: 'Earnings',
      activeIconPath: AssetsConstants.walletActiveIcon,
      inactiveIconPath: AssetsConstants.walletInActiveIcon,
    ),
    BottomNavItem(
      label: 'Profile',
      activeIconPath: AssetsConstants.profileActiveIcon,
      inactiveIconPath: AssetsConstants.profileInActiveIcon,
    ),
  ];

  Future<List<int>> pumpBar(
    WidgetTester tester, {
    int currentIndex = 0,
    List<BottomNavItem> navItems = items,
  }) async {
    final taps = <int>[];
    await tester.pumpWidget(
      pumpTestWidget(
        BottomNavBar(
          currentIndex: currentIndex,
          onTap: taps.add,
          items: navItems,
        ),
      ),
    );
    // The icon swap runs a 200ms AnimatedSwitcher; bounded pumps rather than
    // pumpAndSettle so nothing depends on the transition being finished.
    await tester.pump(const Duration(milliseconds: 300));
    return taps;
  }

  testWidgets('renders one tappable entry per item, with its label', (
    tester,
  ) async {
    printTestDivider('BottomNavBar renders one entry per item, with its label');
    await pumpBar(tester);

    printTestLog(
      'gestures → expected: 4, actual: ${find.byType(GestureDetector).evaluate().length}',
    );
    expect(find.byType(GestureDetector), findsNWidgets(items.length));
    for (final item in items) {
      printTestLog('label → expected: "${item.label}" visible');
      expect(find.text(item.label), findsOneWidget);
    }
  });

  testWidgets('the current tab shows its active icon, the rest inactive', (
    tester,
  ) async {
    printTestDivider('BottomNavBar current tab shows its active icon');
    await pumpBar(tester, currentIndex: 2);

    // _buildNavIcon keys each icon by "<path>-active"/"<path>-inactive", so
    // the key is the cheapest read of which variant is on screen (the SVGs
    // themselves render identically to a finder).
    printTestLog(
      'active icon → expected: ${AssetsConstants.walletActiveIcon}-active present',
    );
    expect(
      find.byKey(const ValueKey('${AssetsConstants.walletActiveIcon}-active')),
      findsOneWidget,
    );
    printTestLog(
      'home icon → expected: ${AssetsConstants.homeInActiveIcon}-inactive present',
    );
    expect(
      find.byKey(
        const ValueKey('${AssetsConstants.homeInActiveIcon}-inactive'),
      ),
      findsOneWidget,
    );
    printTestLog(
      'home active icon → expected: absent, '
      'actual: ${find.byKey(const ValueKey('${AssetsConstants.homeActiveIcon}-active')).evaluate().length}',
    );
    expect(
      find.byKey(const ValueKey('${AssetsConstants.homeActiveIcon}-active')),
      findsNothing,
    );
  });

  testWidgets('tapping a tab reports that tab index', (tester) async {
    printTestDivider('BottomNavBar tapping a tab reports that tab index');
    final taps = await pumpBar(tester);

    await tester.tap(find.text('Earnings'));
    await tester.pump();

    printTestLog('taps → expected: [2], actual: $taps');
    expect(taps, [2]);
  });

  testWidgets('tapping the already-active tab still reports it', (
    tester,
  ) async {
    printTestDivider('BottomNavBar tapping the already-active tab still reports it');
    final taps = await pumpBar(tester, currentIndex: 1);

    await tester.tap(find.text('My Delivery'));
    await tester.pump();

    // NavCubit emits on every call, so the screen must not filter this out
    // here either — MainScreen's back gesture depends on the same behavior.
    printTestLog('taps → expected: [1], actual: $taps');
    expect(taps, [1]);
  });

  testWidgets('the whole cell is tappable, not just the label', (tester) async {
    printTestDivider('BottomNavBar the whole cell is tappable, not just the label');
    final taps = await pumpBar(tester);

    // behavior: HitTestBehavior.opaque — the gap between icon and label counts.
    final cell = tester.getRect(find.byType(GestureDetector).at(3));
    await tester.tapAt(Offset(cell.center.dx, cell.top + 2));
    await tester.pump();

    printTestLog('taps → expected: [3], actual: $taps');
    expect(taps, [3]);
  });

  testWidgets('an item with no icon paths renders no icon and still taps', (
    tester,
  ) async {
    printTestDivider('BottomNavBar an item with no icon paths renders no icon');
    final taps = await pumpBar(
      tester,
      navItems: const [
        BottomNavItem(label: 'Home'),
        BottomNavItem(label: 'Profile'),
      ],
    );

    printTestLog(
      'svg icons → expected: 0, actual: ${find.byType(AppSvgIcon).evaluate().length}',
    );
    expect(find.byType(AppSvgIcon), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    printTestLog('taps → expected: [1], actual: $taps');
    expect(taps, [1]);
  });

  testWidgets('an empty icon path falls back the same way a null one does', (
    tester,
  ) async {
    printTestDivider('BottomNavBar an empty icon path falls back like a null one');
    await pumpBar(
      tester,
      navItems: const [
        BottomNavItem(label: 'Home', activeIconPath: '', inactiveIconPath: ''),
      ],
    );

    printTestLog(
      'svg icons → expected: 0, actual: ${find.byType(AppSvgIcon).evaluate().length}',
    );
    expect(find.byType(AppSvgIcon), findsNothing);
  });

  testWidgets('the active label is bolder than the inactive ones', (
    tester,
  ) async {
    printTestDivider('BottomNavBar the active label is bolder than inactive ones');
    await pumpBar(tester, currentIndex: 0);

    final active = tester.widget<Text>(find.text('Home'));
    final inactive = tester.widget<Text>(find.text('Profile'));

    printTestLog(
      'active weight → expected: ${FontWeight.w600}, actual: ${active.style?.fontWeight}',
    );
    expect(active.style?.fontWeight, FontWeight.w600);
    printTestLog(
      'inactive weight → expected: ${FontWeight.w500}, actual: ${inactive.style?.fontWeight}',
    );
    expect(inactive.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('the indicator sits over the current tab', (tester) async {
    printTestDivider('BottomNavBar the indicator sits over the current tab');
    await pumpBar(tester, currentIndex: 2);

    // Scoped to the bar: MaterialApp's page route puts a PositionedDirectional
    // of its own (the Cupertino back-gesture detector) in the tree too, so a
    // bare find.byType matches two widgets and throws "Too many elements".
    final indicator = tester.widget<PositionedDirectional>(_indicatorFinder);
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final cellWidth = screenWidth / items.length;

    printTestLog(
      'start → expected: ${cellWidth * 2 + cellWidth * 0.2}, actual: ${indicator.start}',
    );
    expect(indicator.start, closeTo(cellWidth * 2 + cellWidth * 0.2, 0.01));
    printTestLog(
      'width → expected: ${cellWidth * 0.6}, actual: ${indicator.width}',
    );
    expect(indicator.width, closeTo(cellWidth * 0.6, 0.01));
  });

  testWidgets('the indicator moves when the current tab changes', (
    tester,
  ) async {
    printTestDivider('BottomNavBar the indicator moves when the tab changes');
    await pumpBar(tester, currentIndex: 0);
    final first = tester.widget<PositionedDirectional>(_indicatorFinder).start;

    await pumpBar(tester, currentIndex: 3);
    final last = tester.widget<PositionedDirectional>(_indicatorFinder).start;

    printTestLog('start → expected: moved right, actual: $first → $last');
    expect(last, greaterThan(first!));
  });
}
