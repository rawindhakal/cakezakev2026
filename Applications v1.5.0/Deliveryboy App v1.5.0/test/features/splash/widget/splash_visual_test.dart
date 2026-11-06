import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/splash/widget/splash_visual.dart';
import 'package:deliveryboy/features/splash/widget/ultra_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// The splash screen's whole visual layer: logo, loader, and an offline
/// overlay. The loader animates forever, so every pump here is bounded and
/// the tree is unmounted before the test ends.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpVisual(WidgetTester tester, {required bool offline}) async {
    await tester.pumpWidget(
      pumpTestWidget(SplashVisual(showNoInternet: offline)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('shows the logo and the loader when online', (tester) async {
    printTestDivider('SplashVisual shows the logo and the loader when online');
    await pumpVisual(tester, offline: false);

    final logo = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
    printTestLog(
      'logo → expected: ${AssetsConstants.splashLogo}, actual: ${logo.path}',
    );
    expect(logo.path, AssetsConstants.splashLogo);
    printTestLog(
      'loader → expected: 1, actual: ${find.byType(UltraLoader).evaluate().length}',
    );
    expect(find.byType(UltraLoader), findsOneWidget);
  });

  testWidgets('no offline overlay while connected', (tester) async {
    printTestDivider('SplashVisual no offline overlay while connected');
    await pumpVisual(tester, offline: false);

    printTestLog(
      'offline overlay → expected: 0, '
      'actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsNothing);
  });

  testWidgets('overlays the offline state without a second scaffold', (
    tester,
  ) async {
    printTestDivider('SplashVisual overlays the offline state, embedded');
    await pumpVisual(tester, offline: true);

    final overlay = tester.widget<AppNoInternetFullScreen>(
      find.byType(AppNoInternetFullScreen),
    );
    // embedded: true — the splash screen already owns the scaffold, and a
    // nested one here would paint its own background over the primary color.
    printTestLog('embedded → expected: true, actual: ${overlay.embedded}');
    expect(overlay.embedded, isTrue);
    printTestLog('onRetry → expected: null, actual: ${overlay.onRetry}');
    expect(overlay.onRetry, isNull);
  });

  testWidgets('keeps the logo and loader mounted underneath while offline', (
    tester,
  ) async {
    printTestDivider('SplashVisual keeps logo and loader mounted while offline');
    await pumpVisual(tester, offline: true);

    // The overlay is a Stack sibling, not a replacement: splash keeps loading
    // in the background and navigates as soon as connectivity returns.
    printTestLog(
      'loader → expected: 1, actual: ${find.byType(UltraLoader).evaluate().length}',
    );
    expect(find.byType(UltraLoader), findsOneWidget);
    printTestLog('logo → expected: still mounted');
    expect(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.splashLogo,
      ),
      findsOneWidget,
    );
  });

  testWidgets('sizes the logo to 40% of the screen width', (tester) async {
    printTestDivider('SplashVisual sizes the logo to 40% of the screen width');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;

    await pumpVisual(tester, offline: false);

    final logoBox = tester.getSize(
      find.ancestor(
        of: find.byType(AppSvgIcon),
        matching: find.byType(SizedBox),
      ).first,
    );
    printTestLog('logo size → expected: 160.0 square, actual: $logoBox');
    expect(logoBox.width, 160.0);
    expect(logoBox.height, 160.0);
  });
}
