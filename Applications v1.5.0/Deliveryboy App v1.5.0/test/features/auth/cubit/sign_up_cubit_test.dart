import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/auth/cubit/sign_up_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void stubRegister(Map<String, dynamic> response) {
    when(
      () => repository.register(
        name: any(named: 'name'),
        mobile: any(named: 'mobile'),
        password: any(named: 'password'),
        confirmPassword: any(named: 'confirmPassword'),
        bonusType: any(named: 'bonusType'),
        email: any(named: 'email'),
        dob: any(named: 'dob'),
        profileImagePath: any(named: 'profileImagePath'),
        nationalIdImagePath: any(named: 'nationalIdImagePath'),
        drivingLicenseImagePath: any(named: 'drivingLicenseImagePath'),
        bonusPercentage: any(named: 'bonusPercentage'),
        bonusMinAmount: any(named: 'bonusMinAmount'),
        bonusMaxAmount: any(named: 'bonusMaxAmount'),
        returnBonusType: any(named: 'returnBonusType'),
        returnBonusPercentage: any(named: 'returnBonusPercentage'),
        returnBonusMinAmount: any(named: 'returnBonusMinAmount'),
        returnBonusMaxAmount: any(named: 'returnBonusMaxAmount'),
        countryId: any(named: 'countryId'),
        countryCode: any(named: 'countryCode'),
        zoneId: any(named: 'zoneId'),
      ),
    ).thenAnswer((_) async => response);
  }

  Future<void> callRegister(SignUpCubit cubit) => cubit.register(
    name: 'John',
    mobile: '999',
    password: 'p1',
    confirmPassword: 'p1',
    bonusType: '1',
  );

  blocTest<SignUpCubit, SignUpState>(
    'emits [Loading, Loaded] carrying the server message on success',
    setUp: () {
      printTestDivider(
        'emits [Loading, Loaded] carrying the server message on success',
      );
      stubRegister({'status': 1, 'message': 'Registered successfully'});
    },
    build: () => SignUpCubit(repository: repository),
    act: callRegister,
    expect: () => [
      isA<SignUpLoading>(),
      isA<SignUpLoaded>().having(
        (s) => s.data,
        'data',
        'Registered successfully',
      ),
    ],
  );

  blocTest<SignUpCubit, SignUpState>(
    'falls back to the localized message when the response has none',
    setUp: () {
      printTestDivider(
        'falls back to the localized message when the response has none',
      );
      stubRegister({'status': 1});
    },
    build: () => SignUpCubit(repository: repository),
    act: callRegister,
    expect: () => [
      isA<SignUpLoading>(),
      isA<SignUpLoaded>().having(
        (s) => s.data,
        'data is a non-empty fallback',
        isNotEmpty,
      ),
    ],
  );

  blocTest<SignUpCubit, SignUpState>(
    'emits [Loading, Error] carrying the API message when register fails',
    setUp: () {
      printTestDivider(
        'emits [Loading, Error] carrying the API message when register fails',
      );
      when(
        () => repository.register(
          name: any(named: 'name'),
          mobile: any(named: 'mobile'),
          password: any(named: 'password'),
          confirmPassword: any(named: 'confirmPassword'),
          bonusType: any(named: 'bonusType'),
          email: any(named: 'email'),
          dob: any(named: 'dob'),
          profileImagePath: any(named: 'profileImagePath'),
          nationalIdImagePath: any(named: 'nationalIdImagePath'),
          drivingLicenseImagePath: any(named: 'drivingLicenseImagePath'),
          bonusPercentage: any(named: 'bonusPercentage'),
          bonusMinAmount: any(named: 'bonusMinAmount'),
          bonusMaxAmount: any(named: 'bonusMaxAmount'),
          returnBonusType: any(named: 'returnBonusType'),
          returnBonusPercentage: any(named: 'returnBonusPercentage'),
          returnBonusMinAmount: any(named: 'returnBonusMinAmount'),
          returnBonusMaxAmount: any(named: 'returnBonusMaxAmount'),
          countryId: any(named: 'countryId'),
          countryCode: any(named: 'countryCode'),
          zoneId: any(named: 'zoneId'),
        ),
      ).thenThrow(const ApiException(message: 'Mobile already registered'));
    },
    build: () => SignUpCubit(repository: repository),
    act: callRegister,
    expect: () => [
      isA<SignUpLoading>(),
      isA<SignUpError>().having(
        (s) => s.message,
        'message',
        'Mobile already registered',
      ),
    ],
  );

  blocTest<SignUpCubit, SignUpState>(
    'reset() returns the cubit to its initial state',
    setUp: () {
      printTestDivider('reset() returns the cubit to its initial state');
      stubRegister({'status': 1, 'message': 'Registered successfully'});
    },
    build: () => SignUpCubit(repository: repository),
    act: (cubit) async {
      await callRegister(cubit);
      cubit.reset();
    },
    expect: () => [
      isA<SignUpLoading>(),
      isA<SignUpLoaded>(),
      isA<SignUpInitial>(),
    ],
  );
}
