import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/features/auth/cubit/sign_in_cubit.dart';
import 'package:deliveryboy/features/auth/screens/sign_in_screen.dart';
import 'package:deliveryboy/features/auth/widgets/login_form.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockSignInCubit signInCubit;
  late MockCountrySettingsCubit countrySettingsCubit;
  late MockConnectivityCubit connectivityCubit;

  setUp(() {
    signInCubit = MockSignInCubit();
    countrySettingsCubit = MockCountrySettingsCubit();
    connectivityCubit = MockConnectivityCubit();
    whenListen(
      signInCubit,
      const Stream<SignInState>.empty(),
      initialState: const SignInInitial(),
    );
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(
    WidgetTester tester, {
    required ConnectivityState connectivity,
  }) async {
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity,
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SignInCubit>.value(value: signInCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        // SignInScreen builds its own AppScaffold, so no extra Scaffold here.
        child: pumpTestWidget(const SignInScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the login form while online', (tester) async {
    printTestDivider('renders the login form while online');
    await pumpScreen(tester, connectivity: ConnectivityConnected());

    printTestLog('LoginForm → expected: 1, actual: ${find.byType(LoginForm).evaluate().length}');
    expect(find.byType(LoginForm), findsOneWidget);
    printTestLog(
      'no-internet screen → expected: absent, actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsNothing);
  });

  testWidgets('replaces the form with the offline screen when disconnected', (
    tester,
  ) async {
    printTestDivider('replaces the form with the offline screen when disconnected');
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());

    // Login can't work offline and this is the root of the unauthed stack, so
    // the whole screen is replaced rather than showing a dismissible banner.
    printTestLog(
      'no-internet screen → expected: 1, actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog('LoginForm → expected: absent, actual: ${find.byType(LoginForm).evaluate().length}');
    expect(find.byType(LoginForm), findsNothing);
  });

  testWidgets('the form is wrapped in a scrollable so the keyboard cannot overflow it', (
    tester,
  ) async {
    printTestDivider(
      'the form is wrapped in a scrollable so the keyboard cannot overflow it',
    );
    await pumpScreen(tester, connectivity: ConnectivityConnected());

    printTestLog(
      'SingleChildScrollView → expected: at least 1, actual: ${find.byType(SingleChildScrollView).evaluate().length}',
    );
    expect(find.byType(SingleChildScrollView), findsWidgets);
    printTestLog('Form → expected: 1, actual: ${find.byType(Form).evaluate().length}');
    expect(find.byType(Form), findsOneWidget);
  });
}
