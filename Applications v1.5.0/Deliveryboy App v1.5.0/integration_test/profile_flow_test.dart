import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/auth/screens/sign_in_screen.dart';
import 'package:deliveryboy/features/notifications/screens/notification_screen.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:deliveryboy/features/profile/screens/account_settings_screen.dart';
import 'package:deliveryboy/features/profile/screens/edit_profile_screen.dart';
import 'package:deliveryboy/features/profile/screens/profile_screen.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/profile_fixtures.dart';

/// The profile tab end to end: real router, real screens, real cubits and
/// repositories, only the network faked. `ProfileScreen` itself never calls
/// `ProfileDetailCubit.loadProfile()`/`CountriesCubit.fetchCountries()` on
/// mount — in the real app those fire once, eagerly, from `main.dart`'s
/// provider `create` (`ProfileDetailCubit()..loadProfile()`,
/// `CountriesCubit()..fetchCountries()`), which `AuthTestApp` deliberately
/// skips so unrelated features' tests aren't forced to stub these endpoints.
/// `_ProfileTabHost` below replicates just that eager kick-off for this
/// suite, standing in for the profile tab's entry point the same way
/// `session_flow_test.dart`'s `mainScreenBuilder` button stands in for it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter adapter;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final dir = await Directory.systemTemp.createTemp('integration_hive_');
    Hive.init(dir.path);
    await Hive.openBox(authBox);
    await Hive.openBox(settingsBox);
    await LocalizationService.instance.loadFromAssets();
  });

  setUp(() async {
    await Hive.box(authBox).clear();
    await AuthHiveBox.instance.saveLoginData(
      auth: AuthModel.fromJson(loginResponseFixture),
    );
    adapter = FakeApiAdapter({
      ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
      ApiEndpoints.editProfile: (_) => profileResponseFixture,
      ApiEndpoints.update: (_) => updatedProfileResponseFixture,
      ApiEndpoints.countries: (_) => countriesResponseFixture,
      ApiEndpoints.zones: (_) => zonesResponseFixture,
      ApiEndpoints.notificationPreferences: (_) => {
        'status': 1,
        'data': <Map<String, dynamic>>[],
      },
      ApiEndpoints.resetPassword: (_) => {
        'status': 1,
        'message': 'Password updated successfully',
      },
    });
    ApiClient().httpClientAdapter = adapter;
  });

  Future<void> waitForResponse(WidgetTester tester) async {
    // The live binding runs on real time, so pump(Duration) alone doesn't let
    // a pending network future complete.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // On-device the real translation asset loads (unlike `flutter test`, where
  // `context.translate` echoes the raw key back), so matching the literal
  // `LanguageLabelKeys.*` key finds nothing here — translate it first.
  String tr(String key) => LocalizationService.instance.translate(key);

  Finder textWith(String key) => find.byWidgetPredicate(
    (w) => w is AppText && w.text == tr(key),
  );

  Future<void> pumpProfileTab(WidgetTester tester) async {
    await tester.pumpWidget(
      AuthTestApp(
        initialRoute: RouteNames.main,
        mainScreenBuilder: (_) => const _ProfileTabHost(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await waitForResponse(tester);
  }

  testWidgets('view → edit → save updates the profile and its header', (
    tester,
  ) async {
    await pumpProfileTab(tester);

    expect(find.textContaining('Alex Johnson'), findsWidgets);

    await tester.tap(textWith(LanguageLabelKeys.edit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Zones for the prefilled country load through a post-frame callback.
    await waitForResponse(tester);

    expect(find.byType(EditProfileScreen), findsOneWidget);
    // Step 1 prefilled from the fetched profile, zone auto-selected from
    // profile.zoneId once the fetched zone list arrives.
    expect(find.text('Alex Johnson'), findsWidgets);
    expect(find.text('North Zone'), findsOneWidget);

    await tester.tap(textWith(LanguageLabelKeys.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(textWith(LanguageLabelKeys.updateProfile));
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.update));
    // Back on the profile tab, showing the name the update responded with.
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.textContaining('Alexander Johnson'), findsWidgets);
  });

  testWidgets('account settings: notifications and change-password open from the settings screen', (
    tester,
  ) async {
    await pumpProfileTab(tester);

    await tester.tap(textWith(LanguageLabelKeys.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AccountSettingsScreen), findsOneWidget);

    await tester.tap(textWith(LanguageLabelKeys.notifications));
    await tester.pump();
    await waitForResponse(tester);
    expect(find.byType(NotificationScreen), findsOneWidget);

    // CustomAppBar's back arrow is a plain IconButton, not the platform
    // back-button widget `pageBack()` looks for.
    await tester.tap(find.byType(IconButton).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AccountSettingsScreen), findsOneWidget);

    await tester.tap(textWith(LanguageLabelKeys.changePassword));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('changing the password clears the session and lands on sign-in', (
    tester,
  ) async {
    await pumpProfileTab(tester);

    await tester.tap(textWith(LanguageLabelKeys.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(textWith(LanguageLabelKeys.changePassword));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'oldpass123');
    await tester.enterText(fields.at(1), 'newpass123');
    await tester.enterText(fields.at(2), 'newpass123');
    await tester.pump();

    await tester.tap(textWith(LanguageLabelKeys.updatePassword));
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.resetPassword));
    // Changing the password forces a logout, unlike a plain profile update.
    expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('a logged-out header shows Guest and Login/Register opens sign-in', (
    tester,
  ) async {
    await Hive.box(authBox).clear();

    await tester.pumpWidget(
      const AuthTestApp(
        initialRoute: RouteNames.main,
        mainScreenBuilder: _guestProfileTab,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(tr(LanguageLabelKeys.guest)), findsOneWidget);
    expect(textWith(LanguageLabelKeys.edit), findsNothing);

    await tester.tap(find.text(tr(LanguageLabelKeys.loginRegister)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SignInScreen), findsOneWidget);
  });
}

Widget _guestProfileTab(BuildContext context) => const ProfileScreen();

/// Replicates `main.dart`'s eager `ProfileDetailCubit()..loadProfile()` /
/// `CountriesCubit()..fetchCountries()`, which `AuthTestApp` skips.
class _ProfileTabHost extends StatefulWidget {
  const _ProfileTabHost();

  @override
  State<_ProfileTabHost> createState() => _ProfileTabHostState();
}

class _ProfileTabHostState extends State<_ProfileTabHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileDetailCubit>().loadProfile();
      context.read<CountriesCubit>().fetchCountries();
    });
  }

  @override
  Widget build(BuildContext context) => const ProfileScreen();
}
