import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/home/widgets/home_header.dart';
import 'package:deliveryboy/features/home/widgets/home_header_profile_row.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpRow(
    WidgetTester tester, {
    String name = 'Alex Johnson',
    String email = 'alex@gmail.com',
    String profileUrl = '',
    bool isOnline = true,
    VoidCallback? onToggle,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(
        HomeHeaderProfileRow(
          name: name,
          email: email,
          profileUrl: profileUrl,
          isOnline: isOnline,
          onToggle: onToggle ?? () {},
        ),
      ),
    );
    await tester.pump();
  }

  group('HomeHeaderProfileRow', () {
    testWidgets('greets the rider by name and shows their email', (
      tester,
    ) async {
      printTestDivider('greets the rider by name and shows their email');
      await pumpRow(tester);

      // Translations aren't loaded in tests, so the greeting label falls back
      // to its raw key.
      printTestLog('greeting → expected: contains "Alex Johnson"');
      expect(
        find.textContaining('Alex Johnson'),
        findsOneWidget,
      );
      printTestLog('email → expected: "alex@gmail.com" visible');
      expect(find.text('alex@gmail.com'), findsOneWidget);
    });

    testWidgets('falls back to the name initial when there is no avatar url', (
      tester,
    ) async {
      printTestDivider('falls back to the name initial when there is no avatar url');
      await pumpRow(tester, name: 'alex johnson');

      printTestLog('initial → expected: "A" visible');
      expect(find.text('A'), findsOneWidget);
      printTestLog(
        'network image → expected: absent, actual: ${find.byType(AppNetworkImage).evaluate().length}',
      );
      expect(find.byType(AppNetworkImage), findsNothing);
    });

    testWidgets('falls back to D when the name is empty too', (tester) async {
      printTestDivider('falls back to D when the name is empty too');
      await pumpRow(tester, name: '');

      printTestLog('initial → expected: "D" visible');
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('renders the avatar image when a url is given', (tester) async {
      printTestDivider('renders the avatar image when a url is given');
      await pumpRow(tester, profileUrl: 'https://example.com/avatar.webp');

      printTestLog(
        'network image → expected: 1, actual: ${find.byType(AppNetworkImage).evaluate().length}',
      );
      expect(find.byType(AppNetworkImage), findsOneWidget);
      printTestLog('initial → expected: absent, actual: ${find.text('A').evaluate().length}');
      expect(find.text('A'), findsNothing);
    });

    testWidgets('shows the online label while online', (tester) async {
      printTestDivider('shows the online label while online');
      await pumpRow(tester, isOnline: true);

      printTestLog('label → expected: "${LanguageLabelKeys.online}" visible');
      expect(find.text(LanguageLabelKeys.online), findsOneWidget);
      printTestLog('offline label → expected: absent');
      expect(find.text(LanguageLabelKeys.offline), findsNothing);
    });

    testWidgets('shows the offline label while offline', (tester) async {
      printTestDivider('shows the offline label while offline');
      await pumpRow(tester, isOnline: false);

      printTestLog('label → expected: "${LanguageLabelKeys.offline}" visible');
      expect(find.text(LanguageLabelKeys.offline), findsOneWidget);
    });

    testWidgets('tapping the status pill invokes onToggle', (tester) async {
      printTestDivider('tapping the status pill invokes onToggle');
      var toggled = false;
      await pumpRow(tester, onToggle: () => toggled = true);

      // The pill is the row's only GestureDetector — the avatar and text are
      // not tappable.
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      printTestLog('onToggle called → expected: true, actual: $toggled');
      expect(toggled, isTrue);
    });
  });

  group('HomeHeader', () {
    testWidgets('renders the profile row inside a pinned sliver header', (
      tester,
    ) async {
      printTestDivider('renders the profile row inside a pinned sliver header');
      // HomeHeader is a sliver, so it only lays out inside a CustomScrollView.
      await tester.pumpWidget(
        pumpTestWidget(
          CustomScrollView(
            slivers: [
              const HomeHeader(
                name: 'Alex Johnson',
                email: 'alex@gmail.com',
                profileUrl: '',
                isOnline: true,
                onToggle: _noop,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1200)),
            ],
          ),
        ),
      );
      await tester.pump();

      printTestLog(
        'profile row → expected: 1, actual: ${find.byType(HomeHeaderProfileRow).evaluate().length}',
      );
      expect(find.byType(HomeHeaderProfileRow), findsOneWidget);

      final header = tester.widget<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      printTestLog('pinned → expected: true, actual: ${header.pinned}');
      expect(header.pinned, isTrue);
    });

    testWidgets('stays on screen after the dashboard is scrolled', (
      tester,
    ) async {
      printTestDivider('stays on screen after the dashboard is scrolled');
      await tester.pumpWidget(
        pumpTestWidget(
          CustomScrollView(
            slivers: [
              const HomeHeader(
                name: 'Alex Johnson',
                email: 'alex@gmail.com',
                profileUrl: '',
                isOnline: true,
                onToggle: _noop,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      );
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(800);
      await tester.pump();

      printTestLog(
        'profile row after scrolling → expected: still 1, actual: ${find.byType(HomeHeaderProfileRow).evaluate().length}',
      );
      expect(find.byType(HomeHeaderProfileRow), findsOneWidget);
    });
  });
}

void _noop() {}
