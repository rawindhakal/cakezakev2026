import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/profile/widgets/profile_menu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Finder svgWith(String path) =>
      find.byWidgetPredicate((w) => w is AppSvgIcon && w.path == path);

  group('ProfileSectionLabel', () {
    testWidgets('renders the text it is given', (tester) async {
      printTestDivider('ProfileSectionLabel renders its text');
      await tester.pumpWidget(pumpTestWidget(const ProfileSectionLabel('Account')));

      printTestLog(
        'label → expected: 1 "Account", actual: ${appTextWith('Account').evaluate().length}',
      );
      expect(appTextWith('Account'), findsOneWidget);
    });
  });

  group('ProfileMenuCard', () {
    testWidgets('renders a title, one row per item, and a divider between rows', (
      tester,
    ) async {
      printTestDivider('ProfileMenuCard renders title, rows and dividers');
      await tester.pumpWidget(
        pumpTestWidget(
          ProfileMenuCard(
            title: 'General',
            items: [
              ProfileMenuItemData(
                iconPath: AssetsConstants.notificationIcon,
                label: 'Notifications',
                onTap: () {},
              ),
              ProfileMenuItemData(
                iconPath: AssetsConstants.passwordIcon,
                label: 'Change password',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      printTestLog(
        'title → expected: 1 "General", actual: ${appTextWith('General').evaluate().length}',
      );
      expect(appTextWith('General'), findsOneWidget);
      printTestLog(
        'rows → expected: 2 InkWells, actual: ${find.byType(InkWell).evaluate().length}',
      );
      expect(find.byType(InkWell), findsNWidgets(2));
      // One divider under the title, one between the two rows — the last row
      // gets none.
      printTestLog(
        'dividers → expected: 2, actual: ${find.byType(Divider).evaluate().length}',
      );
      expect(find.byType(Divider), findsNWidgets(2));
      printTestLog(
        'item icon → expected: 1 notification icon, '
        'actual: ${svgWith(AssetsConstants.notificationIcon).evaluate().length}',
      );
      expect(svgWith(AssetsConstants.notificationIcon), findsOneWidget);
      // Every row carries a chevron.
      printTestLog(
        'chevrons → expected: 2, actual: ${svgWith(AssetsConstants.arrowRightIcon).evaluate().length}',
      );
      expect(svgWith(AssetsConstants.arrowRightIcon), findsNWidgets(2));
    });

    testWidgets('omits the title block when no title is given', (tester) async {
      printTestDivider('ProfileMenuCard omits the title block when title is null');
      await tester.pumpWidget(
        pumpTestWidget(
          ProfileMenuCard(
            items: [
              ProfileMenuItemData(
                iconPath: AssetsConstants.logoutIcon,
                label: 'Logout',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      // A single item with no title means no divider at all.
      printTestLog(
        'dividers → expected: 0, actual: ${find.byType(Divider).evaluate().length}',
      );
      expect(find.byType(Divider), findsNothing);
      printTestLog(
        'row → expected: 1 "Logout", actual: ${appTextWith('Logout').evaluate().length}',
      );
      expect(appTextWith('Logout'), findsOneWidget);
    });

    testWidgets('renders a trailing string and a trailing widget when given', (
      tester,
    ) async {
      printTestDivider('ProfileMenuCard renders trailing string and widget');
      await tester.pumpWidget(
        pumpTestWidget(
          ProfileMenuCard(
            items: [
              ProfileMenuItemData(
                iconPath: AssetsConstants.languageIcon,
                label: 'Change language',
                trailing: 'English (EN)',
                onTap: () {},
              ),
              ProfileMenuItemData(
                iconPath: AssetsConstants.themeIcon,
                label: 'Change theme',
                trailingWidget: const Icon(Icons.dark_mode),
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      printTestLog(
        'trailing text → expected: 1 "English (EN)", '
        'actual: ${appTextWith('English (EN)').evaluate().length}',
      );
      expect(appTextWith('English (EN)'), findsOneWidget);
      printTestLog(
        'trailing widget → expected: 1 dark_mode icon, '
        'actual: ${find.byIcon(Icons.dark_mode).evaluate().length}',
      );
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('taps fire the tapped row callback only', (tester) async {
      printTestDivider('ProfileMenuCard taps fire only the tapped row callback');
      var first = 0;
      var second = 0;
      await tester.pumpWidget(
        pumpTestWidget(
          ProfileMenuCard(
            items: [
              ProfileMenuItemData(
                iconPath: AssetsConstants.settingsIcon,
                label: 'Settings',
                onTap: () => first++,
              ),
              ProfileMenuItemData(
                iconPath: AssetsConstants.logoutIcon,
                label: 'Logout',
                onTap: () => second++,
              ),
            ],
          ),
        ),
      );

      await tester.tap(appTextWith('Logout'));
      await tester.pump();

      printTestLog('first row taps → expected: 0, actual: $first');
      expect(first, 0);
      printTestLog('second row taps → expected: 1, actual: $second');
      expect(second, 1);
    });
  });

  group('ProfileExpandableMenuSection', () {
    Widget buildSection({VoidCallback? onPrivacyTap}) =>
        pumpTestWidget(
          ProfileExpandableMenuSection(
            iconPath: AssetsConstants.helpPolicyIcon,
            label: 'Help & policies',
            title: 'Help & policies',
            children: [
              ProfileMenuItemData(
                iconPath: AssetsConstants.helpPolicyIcon,
                label: 'Privacy policy',
                onTap: onPrivacyTap ?? () {},
              ),
              ProfileMenuItemData(
                iconPath: AssetsConstants.helpPolicyIcon,
                label: 'Terms and conditions',
                onTap: () {},
              ),
            ],
          ),
        );

    testWidgets('starts collapsed with its children hidden', (tester) async {
      printTestDivider('ProfileExpandableMenuSection starts collapsed');
      await tester.pumpWidget(buildSection());
      // The cross-fade animation runs for 250ms; settle it before asserting.
      await tester.pumpAndSettle();

      printTestLog(
        'header → expected: visible, actual: ${find.byType(AnimatedCrossFade).evaluate().length} cross-fade(s)',
      );
      expect(find.byType(AnimatedCrossFade), findsOneWidget);
      final crossFade = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      printTestLog(
        'crossFadeState → expected: showFirst, actual: ${crossFade.crossFadeState}',
      );
      expect(crossFade.crossFadeState, CrossFadeState.showFirst);
      printTestLog(
        'chevron → expected: 1 arrow-down, '
        'actual: ${svgWith(AssetsConstants.arrowDownIcon).evaluate().length}',
      );
      expect(svgWith(AssetsConstants.arrowDownIcon), findsOneWidget);
    });

    testWidgets('tapping the header expands and reveals the children', (
      tester,
    ) async {
      printTestDivider('ProfileExpandableMenuSection expands on tap');
      await tester.pumpWidget(buildSection());
      await tester.pumpAndSettle();

      await tester.tap(appTextWith('Help & policies').last);
      await tester.pumpAndSettle();

      final crossFade = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      printTestLog(
        'crossFadeState → expected: showSecond, actual: ${crossFade.crossFadeState}',
      );
      expect(crossFade.crossFadeState, CrossFadeState.showSecond);
      printTestLog(
        'children → expected: "Privacy policy" visible, '
        'actual: ${appTextWith('Privacy policy').evaluate().length}',
      );
      expect(appTextWith('Privacy policy'), findsOneWidget);
      final rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      printTestLog('chevron turns → expected: 0.5, actual: ${rotation.turns}');
      expect(rotation.turns, 0.5);
    });

    testWidgets('tapping an expanded child fires its callback', (tester) async {
      printTestDivider('ProfileExpandableMenuSection child tap fires callback');
      var taps = 0;
      await tester.pumpWidget(buildSection(onPrivacyTap: () => taps++));
      await tester.pumpAndSettle();

      await tester.tap(appTextWith('Help & policies').last);
      await tester.pumpAndSettle();
      await tester.tap(appTextWith('Privacy policy'));
      await tester.pump();

      printTestLog('privacy taps → expected: 1, actual: $taps');
      expect(taps, 1);
    });

    testWidgets('tapping the header again collapses it', (tester) async {
      printTestDivider('ProfileExpandableMenuSection collapses on a second tap');
      await tester.pumpWidget(buildSection());
      await tester.pumpAndSettle();

      await tester.tap(appTextWith('Help & policies').last);
      await tester.pumpAndSettle();
      await tester.tap(appTextWith('Help & policies').last);
      await tester.pumpAndSettle();

      final crossFade = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      printTestLog(
        'crossFadeState → expected: showFirst, actual: ${crossFade.crossFadeState}',
      );
      expect(crossFade.crossFadeState, CrossFadeState.showFirst);
    });
  });
}
