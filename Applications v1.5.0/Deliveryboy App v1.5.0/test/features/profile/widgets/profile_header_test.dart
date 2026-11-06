import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/features/profile/widgets/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/test_logging.dart';

/// ProfileHeader reads everything it shows straight out of `AuthHiveBox`
/// through a `ValueListenableBuilder`, so each test seeds the temp-dir box
/// rather than stubbing a cubit.
void main() {
  late List<RouteSettings> pushed;

  setUp(() async {
    await HiveTestHelper.setUp(authBox);
    pushed = [];
  });

  tearDown(() => HiveTestHelper.tearDown(authBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  // A Hive write started in a `testWidgets` body belongs to the test's own
  // zone, whose fake clock never runs the event loop the write completes on —
  // the pending future then blocks `tearDown`'s `box.close()` forever, with no
  // failure message. Seeding through `runAsync` puts the write on the real
  // event loop, where it actually finishes.
  Future<void> seedLoggedIn(
    WidgetTester tester, {
    String name = 'Alex Johnson',
    String email = 'alex@gmail.com',
    String profileUrl = '',
  }) => tester.runAsync(
    () => Hive.box(authBox).putAll({
      kIsLoggedIn: true,
      kUserName: name,
      kUserEmail: email,
      kUserProfile: profileUrl,
    }),
  );

  Future<void> pumpHeader(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const Scaffold(body: ProfileHeader()),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute(
            builder: (_) => Scaffold(body: Text('route:${settings.name}')),
            settings: settings,
          );
        },
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the stored name and email when logged in', (tester) async {
    printTestDivider('ProfileHeader shows the stored name and email');
    await seedLoggedIn(tester);
    await pumpHeader(tester);

    printTestLog(
      'name → expected: 1 "Alex Johnson", actual: ${appTextWith('Alex Johnson').evaluate().length}',
    );
    expect(appTextWith('Alex Johnson'), findsOneWidget);
    printTestLog(
      'email → expected: 1 "alex@gmail.com", actual: ${appTextWith('alex@gmail.com').evaluate().length}',
    );
    expect(appTextWith('alex@gmail.com'), findsOneWidget);
    printTestLog(
      'edit button → expected: 1 "${LanguageLabelKeys.edit}", '
      'actual: ${appTextWith(LanguageLabelKeys.edit).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.edit), findsOneWidget);
  });

  testWidgets('shows the guest prompt and hides Edit when logged out', (
    tester,
  ) async {
    printTestDivider('ProfileHeader shows the guest prompt when logged out');
    await pumpHeader(tester);

    printTestLog(
      'guest → expected: 1 "${LanguageLabelKeys.guest}", '
      'actual: ${appTextWith(LanguageLabelKeys.guest).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.guest), findsOneWidget);
    printTestLog(
      'login prompt → expected: 1 "${LanguageLabelKeys.loginRegister}", '
      'actual: ${appTextWith(LanguageLabelKeys.loginRegister).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.loginRegister), findsOneWidget);
    printTestLog(
      'edit button → expected: 0, actual: ${appTextWith(LanguageLabelKeys.edit).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.edit), findsNothing);
  });

  testWidgets('falls back to the user icon when no profile image is stored', (
    tester,
  ) async {
    printTestDivider('ProfileHeader falls back to the user icon');
    await seedLoggedIn(tester);
    await pumpHeader(tester);

    printTestLog(
      'network image → expected: 0, actual: ${find.byType(AppNetworkImage).evaluate().length}',
    );
    expect(find.byType(AppNetworkImage), findsNothing);
    final icon = find.byWidgetPredicate(
      (w) => w is AppSvgIcon && w.path == AssetsConstants.userIcon,
    );
    printTestLog('user icon → expected: 1, actual: ${icon.evaluate().length}');
    expect(icon, findsOneWidget);
  });

  testWidgets('renders the avatar image when a profile URL is stored', (
    tester,
  ) async {
    printTestDivider('ProfileHeader renders the stored avatar');
    await seedLoggedIn(tester, profileUrl: 'https://example.test/avatar.png');
    await pumpHeader(tester);

    printTestLog(
      'network image → expected: 1, actual: ${find.byType(AppNetworkImage).evaluate().length}',
    );
    expect(find.byType(AppNetworkImage), findsOneWidget);
  });

  testWidgets('Edit pushes the edit-profile route', (tester) async {
    printTestDivider('ProfileHeader Edit pushes the edit-profile route');
    await seedLoggedIn(tester);
    await pumpHeader(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.edit));
    await tester.pump();

    printTestLog(
      'pushed → expected: [${RouteNames.editProfile}], actual: ${pushed.map((r) => r.name)}',
    );
    expect(pushed.map((r) => r.name), [RouteNames.editProfile]);
  });

  testWidgets('the login prompt pushes the login route', (tester) async {
    printTestDivider('ProfileHeader login prompt pushes the login route');
    await pumpHeader(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.loginRegister));
    await tester.pump();

    printTestLog(
      'pushed → expected: [${RouteNames.login}], actual: ${pushed.map((r) => r.name)}',
    );
    expect(pushed.map((r) => r.name), [RouteNames.login]);
  });

  testWidgets('a Hive write refreshes the header in place', (tester) async {
    printTestDivider('ProfileHeader refreshes when the auth box changes');
    await seedLoggedIn(tester, name: 'Alex Johnson');
    await pumpHeader(tester);

    await tester.runAsync(
      () => Hive.box(authBox).put(kUserName, 'Alexandra Johnson'),
    );
    await tester.pump();

    printTestLog(
      'name → expected: 1 "Alexandra Johnson", '
      'actual: ${appTextWith('Alexandra Johnson').evaluate().length}',
    );
    expect(appTextWith('Alexandra Johnson'), findsOneWidget);
  });
}
