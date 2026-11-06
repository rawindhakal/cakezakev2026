import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/chat_status_icon.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpIcon(WidgetTester tester, MessageStatus status) async {
    await tester.pumpWidget(pumpTestWidget(ChatStatusIcon(status: status)));
    await tester.pump();
  }

  testWidgets('sending renders a small spinner, not an svg icon', (tester) async {
    printTestDivider('ChatStatusIcon sending renders a small spinner, not an svg icon');
    await pumpIcon(tester, MessageStatus.sending);

    printTestLog(
      'spinner → expected: 1, actual: ${find.byType(ShimmerInline).evaluate().length}',
    );
    expect(find.byType(ShimmerInline), findsOneWidget);
    final loading = tester.widget<ShimmerInline>(find.byType(ShimmerInline));
    printTestLog('spinner size → expected: 10, actual: ${loading.size}');
    expect(loading.size, 10);
    printTestLog(
      'svg icon → expected: none, actual: ${find.byType(AppSvgIcon).evaluate().length}',
    );
    expect(find.byType(AppSvgIcon), findsNothing);
  });

  testWidgets('sent renders the read-check icon at reduced opacity onPrimary', (tester) async {
    printTestDivider('ChatStatusIcon sent renders the read-check icon at reduced opacity onPrimary');
    await pumpIcon(tester, MessageStatus.sent);

    final icon = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
    printTestLog(
      'path → expected: ${AssetsConstants.checkReadIcon}, actual: ${icon.path}',
    );
    expect(icon.path, AssetsConstants.checkReadIcon);
    final scheme = Theme.of(tester.element(find.byType(ChatStatusIcon))).colorScheme;
    printTestLog(
      'colour → expected: ${scheme.onPrimary.withValues(alpha: 0.7)}, actual: ${icon.color}',
    );
    expect(icon.color, scheme.onPrimary.withValues(alpha: 0.7));
  });

  testWidgets('failed renders the info-circle icon in the error colour', (tester) async {
    printTestDivider('ChatStatusIcon failed renders the info-circle icon in the error colour');
    await pumpIcon(tester, MessageStatus.failed);

    final icon = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
    printTestLog(
      'path → expected: ${AssetsConstants.infoCircleIcon}, actual: ${icon.path}',
    );
    expect(icon.path, AssetsConstants.infoCircleIcon);
    final scheme = Theme.of(tester.element(find.byType(ChatStatusIcon))).colorScheme;
    printTestLog('colour → expected: ${scheme.error}, actual: ${icon.color}');
    expect(icon.color, scheme.error);
  });

  testWidgets('every status renders exactly one visible indicator', (tester) async {
    printTestDivider('ChatStatusIcon every status renders exactly one visible indicator');
    for (final status in MessageStatus.values) {
      await pumpIcon(tester, status);
      final count = status == MessageStatus.sending
          ? find.byType(ShimmerInline).evaluate().length
          : find.byType(AppSvgIcon).evaluate().length;
      printTestLog('status $status → expected: 1, actual: $count');
      expect(count, 1);
    }
  });
}
