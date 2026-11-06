import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/auth/models/auth_model.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:customer/features/profile/widgets/profile_dialogs.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

/// `showLogoutDialog`/`showDeleteAccountDialog`/`showChangePasswordSheet`
/// each built their own cubit internally (`BlocProvider(create: (_) =>
/// XCubit())`) with no seam to inject a repository — but `AuthRepository()`'s
/// own default constructor eagerly reads `FirebaseAuth.instance` in its
/// initializer list (`_firebaseAuth = firebaseAuth ?? FirebaseAuth.instance`),
/// which throws under `flutter test` even though none of `logout`/
/// `deleteAccount`/`changePassword` ever touch it. That made these three
/// dialogs entirely unwidget-testable — not just their Firebase-touching
/// branches, but *construction itself* — until `profile_dialogs.dart` grew
/// an optional `{AuthRepository? repository}` param on each `show*`
/// function, threaded straight to the cubit, mirroring the `{AuthRepository?
/// repository}` seam every cubit in this codebase already has. All three
/// underlying cubits (`LogoutCubit`, `DeleteAccountCubit`,
/// `ChangePasswordCubit`) use `ApiErrorGuard` and never touch
/// Analytics/Crashlytics, so — unlike `ProfileUpdateCubit` — every branch
/// (loading/success/error) is fully testable once construction itself no
/// longer throws.
void main() {
  late MockAuthRepository repository;

  setUp(() async {
    repository = MockAuthRepository();
    await HiveTestHelper.setUpBoxes([authBox, settingsBox]);
    await AuthHiveBox.instance.saveLoginData(
      userLogin: AuthModel(data: AuthModelData(accessToken: 'tok')),
    );
  });

  tearDown(() => HiveTestHelper.tearDownBoxes([authBox, settingsBox]));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  /// Advances a success path that both spins and writes to Hive.
  ///
  /// Two separate hazards, either of which alone breaks a naive
  /// `pumpAndSettle()`:
  ///
  /// 1. `AppButton(isLoading: true)` renders a `LoadingWidget`
  ///    (`CircularProgressIndicator`), which schedules a frame forever — the
  ///    tree never goes quiet, so `pumpAndSettle` spins to its 10-minute
  ///    timeout. Bounded `pump`s are required instead.
  /// 2. Every success path here awaits a real Hive write
  ///    (`clearAuth()`), whose Future completes only after actual disk I/O.
  ///    `tester.pump()` advances *fake* async time and never lets that
  ///    complete, so the `emit(XLoaded())` sitting after the `await` never
  ///    runs and the navigation the listener would have triggered silently
  ///    never happens. `tester.runAsync` is the only thing that lets real
  ///    I/O finish.
  Future<void> pumpPastLoading(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpHarness(
    WidgetTester tester,
    void Function(BuildContext, AuthRepository) onOpen,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        routes: {
          RouteNames.login: (_) => const Scaffold(body: Text('Login Screen')),
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => onOpen(context, repository),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showLogoutDialog', () {
    testWidgets('renders the confirm/cancel labels', (tester) async {
      printTestDivider('showLogoutDialog renders the confirm/cancel labels');
      await pumpHarness(
        tester,
        (ctx, repo) => showLogoutDialog(ctx, repository: repo),
      );

      expect(find.text(LanguageLabelKeys.logoutAnyway), findsOneWidget);
      expect(find.text(LanguageLabelKeys.keepLogin), findsOneWidget);
    });

    testWidgets('cancel dismisses without navigating or calling the API', (
      tester,
    ) async {
      printTestDivider(
        'showLogoutDialog cancel dismisses without navigating or calling the API',
      );
      await pumpHarness(
        tester,
        (ctx, repo) => showLogoutDialog(ctx, repository: repo),
      );
      await tester.tap(find.text(LanguageLabelKeys.keepLogin));
      await tester.pumpAndSettle();

      printTestLog('landed on Login Screen after cancel → expected: false');
      expect(find.text('Login Screen'), findsNothing);
      verifyNever(() => repository.logout());
    });

    testWidgets('confirm logs out, clears the token, and lands on login', (
      tester,
    ) async {
      printTestDivider(
        'showLogoutDialog confirm logs out, clears token, lands on login',
      );
      when(() => repository.logout()).thenAnswer((_) async {});

      await pumpHarness(
        tester,
        (ctx, repo) => showLogoutDialog(ctx, repository: repo),
      );
      await tester.tap(find.text(LanguageLabelKeys.logoutAnyway));
      await pumpPastLoading(tester);

      printTestLog(
        'token after logout → expected: empty, actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken() ?? '', isEmpty);
      printTestLog('navigated to Login Screen → expected: true');
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('confirm surfaces the API error and stays put', (
      tester,
    ) async {
      printTestDivider('showLogoutDialog confirm surfaces the API error');
      when(
        () => repository.logout(),
      ).thenThrow(const ApiException(message: 'Logout failed'));

      await pumpHarness(
        tester,
        (ctx, repo) => showLogoutDialog(ctx, repository: repo),
      );
      await tester.tap(find.text(LanguageLabelKeys.logoutAnyway));
      await tester.pumpAndSettle();

      printTestLog('error snackbar text → expected: "Logout failed"');
      expect(find.text('Logout failed'), findsOneWidget);
      printTestLog(
        'token untouched → expected: "tok", actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken(), 'tok');
    });
  });

  group('showDeleteAccountDialog', () {
    testWidgets('renders the confirm/cancel labels', (tester) async {
      printTestDivider(
        'showDeleteAccountDialog renders the confirm/cancel labels',
      );
      await pumpHarness(
        tester,
        (ctx, repo) => showDeleteAccountDialog(ctx, repository: repo),
      );

      expect(find.text(LanguageLabelKeys.delete), findsOneWidget);
      expect(find.text(LanguageLabelKeys.cancel), findsOneWidget);
    });

    testWidgets('confirm deletes the account and lands on login', (
      tester,
    ) async {
      printTestDivider(
        'showDeleteAccountDialog confirm deletes account, lands on login',
      );
      when(() => repository.deleteAccount()).thenAnswer((_) async {});

      await pumpHarness(
        tester,
        (ctx, repo) => showDeleteAccountDialog(ctx, repository: repo),
      );
      await tester.tap(find.text(LanguageLabelKeys.delete));
      await pumpPastLoading(tester);

      printTestLog(
        'token after delete → expected: empty, actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken() ?? '', isEmpty);
      printTestLog('navigated to Login Screen → expected: true');
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('confirm surfaces the API error and stays put', (
      tester,
    ) async {
      printTestDivider(
        'showDeleteAccountDialog confirm surfaces the API error',
      );
      when(
        () => repository.deleteAccount(),
      ).thenThrow(const ApiException(message: 'Delete failed'));

      await pumpHarness(
        tester,
        (ctx, repo) => showDeleteAccountDialog(ctx, repository: repo),
      );
      await tester.tap(find.text(LanguageLabelKeys.delete));
      await tester.pumpAndSettle();

      printTestLog('error snackbar text → expected: "Delete failed"');
      expect(find.text('Delete failed'), findsOneWidget);
    });
  });

  group('showChangePasswordSheet', () {
    Future<void> fillForm(
      WidgetTester tester, {
      String oldPassword = 'OldPass1',
      String newPassword = 'NewPass1',
      String confirmPassword = 'NewPass1',
    }) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), oldPassword);
      await tester.enterText(fields.at(1), newPassword);
      await tester.enterText(fields.at(2), confirmPassword);
      await tester.pump();
    }

    testWidgets('renders the three password fields', (tester) async {
      printTestDivider(
        'showChangePasswordSheet renders the three password fields',
      );
      await pumpHarness(
        tester,
        (ctx, repo) => showChangePasswordSheet(ctx, repository: repo),
      );

      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('blocks submit and shows validation errors when empty', (
      tester,
    ) async {
      printTestDivider(
        'showChangePasswordSheet blocks submit and shows validation errors when empty',
      );
      await pumpHarness(
        tester,
        (ctx, repo) => showChangePasswordSheet(ctx, repository: repo),
      );
      await tester.tap(find.text(LanguageLabelKeys.changePassword).last);
      await tester.pumpAndSettle();

      printTestLog('still on the sheet, no navigation → expected: true');
      expect(find.text('Login Screen'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(3));
      verifyNever(
        () => repository.changePassword(
          oldPassword: any(named: 'oldPassword'),
          newPassword: any(named: 'newPassword'),
          newPasswordConfirmation: any(named: 'newPasswordConfirmation'),
        ),
      );
    });

    testWidgets(
      'submitting a valid form changes the password, clears the session, '
      'and lands on login',
      (tester) async {
        printTestDivider(
          'showChangePasswordSheet valid submit changes password, clears session, lands on login',
        );
        when(
          () => repository.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
            newPasswordConfirmation: any(named: 'newPasswordConfirmation'),
          ),
        ).thenAnswer(
          (_) async => {'status': 1, 'message': 'Password changed'},
        );

        await pumpHarness(
          tester,
          (ctx, repo) => showChangePasswordSheet(ctx, repository: repo),
        );
        await fillForm(tester);
        await tester.tap(find.text(LanguageLabelKeys.changePassword).last);
        await pumpPastLoading(tester);

        printTestLog(
          'token after change-password → expected: empty, actual: "${AuthHiveBox.instance.getToken()}"',
        );
        expect(AuthHiveBox.instance.getToken() ?? '', isEmpty);
        printTestLog('navigated to Login Screen → expected: true');
        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets('surfaces the API error and keeps the session intact', (
      tester,
    ) async {
      printTestDivider(
        'showChangePasswordSheet surfaces the API error and keeps the session intact',
      );
      when(
        () => repository.changePassword(
          oldPassword: any(named: 'oldPassword'),
          newPassword: any(named: 'newPassword'),
          newPasswordConfirmation: any(named: 'newPasswordConfirmation'),
        ),
      ).thenThrow(const ApiException(message: 'Old password incorrect'));

      await pumpHarness(
        tester,
        (ctx, repo) => showChangePasswordSheet(ctx, repository: repo),
      );
      await fillForm(tester);
      await tester.tap(find.text(LanguageLabelKeys.changePassword).last);
      await tester.pumpAndSettle();

      printTestLog(
        'error snackbar text → expected: "Old password incorrect"',
      );
      expect(find.text('Old password incorrect'), findsOneWidget);
      printTestLog(
        'token untouched → expected: "tok", actual: "${AuthHiveBox.instance.getToken()}"',
      );
      expect(AuthHiveBox.instance.getToken(), 'tok');
    });
  });
}
