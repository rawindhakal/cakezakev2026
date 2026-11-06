import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/profile/cubit/profile_update_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;
  late AuthModel updated;

  void stubUpdate() {
    when(
      () => repository.updateProfile(
        name: any(named: 'name'),
        mobile: any(named: 'mobile'),
        email: any(named: 'email'),
        address: any(named: 'address'),
        dob: any(named: 'dob'),
        bankAccountNumber: any(named: 'bankAccountNumber'),
        bankName: any(named: 'bankName'),
        accountName: any(named: 'accountName'),
        ifscCode: any(named: 'ifscCode'),
        bonusType: any(named: 'bonusType'),
        bonusPercentage: any(named: 'bonusPercentage'),
        bonusMinAmount: any(named: 'bonusMinAmount'),
        bonusMaxAmount: any(named: 'bonusMaxAmount'),
        returnBonusType: any(named: 'returnBonusType'),
        returnBonusPercentage: any(named: 'returnBonusPercentage'),
        returnBonusMinAmount: any(named: 'returnBonusMinAmount'),
        returnBonusMaxAmount: any(named: 'returnBonusMaxAmount'),
        profileImagePath: any(named: 'profileImagePath'),
        nationalIdImagePath: any(named: 'nationalIdImagePath'),
        drivingLicenseImagePath: any(named: 'drivingLicenseImagePath'),
        countryId: any(named: 'countryId'),
        zoneId: any(named: 'zoneId'),
      ),
    ).thenAnswer((_) async => updated);
  }

  setUp(() {
    repository = MockAuthRepository();
    updated = AuthModel.fromJson(
      jsonDecode(File('test/fixtures/auth/login_response.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('starts in ProfileUpdateInitial', () {
    printTestDivider('ProfileUpdateCubit starts in ProfileUpdateInitial');
    final cubit = ProfileUpdateCubit(repository: repository);
    printTestLog(
      'initial state → expected: ProfileUpdateInitial, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<ProfileUpdateInitial>());
    cubit.close();
  });

  blocTest<ProfileUpdateCubit, ProfileUpdateState>(
    'updateProfile emits [Loading, Loaded] and returns the repository model as-is',
    setUp: () {
      printTestDivider(
        'ProfileUpdateCubit.updateProfile emits [Loading, Loaded] on success',
      );
      stubUpdate();
    },
    build: () => ProfileUpdateCubit(repository: repository),
    act: (cubit) => cubit.updateProfile(name: 'Alex Johnson', mobile: '1234567890'),
    expect: () => [isA<ProfileUpdateLoading>(), isA<ProfileUpdateLoaded>()],
    verify: (cubit) {
      final data = (cubit.state as ProfileUpdateLoaded).data;
      // Unlike ProfileDetailCubit, this cubit forwards the repository's own
      // instance rather than re-parsing it.
      printTestLog(
        'emitted instance → expected: the repository model, actual: identical=${identical(data, updated)}',
      );
      expect(identical(data, updated), isTrue);
    },
  );

  blocTest<ProfileUpdateCubit, ProfileUpdateState>(
    'updateProfile forwards every field it was given to the repository',
    setUp: () {
      printTestDivider(
        'ProfileUpdateCubit.updateProfile forwards every field to the repository',
      );
      stubUpdate();
    },
    build: () => ProfileUpdateCubit(repository: repository),
    act: (cubit) => cubit.updateProfile(
      name: 'Alex Johnson',
      mobile: '1234567890',
      email: 'alex@gmail.com',
      address: 'Mumbai',
      dob: '1989-08-01',
      bankAccountNumber: '9000323402965',
      bankName: 'Bank of Globe',
      accountName: 'Alex Johnson',
      ifscCode: 'BANGLOB',
      bonusType: '1',
      bonusPercentage: '10',
      bonusMinAmount: '40',
      bonusMaxAmount: '60',
      returnBonusType: '1',
      returnBonusPercentage: '10',
      returnBonusMinAmount: '40',
      returnBonusMaxAmount: '60',
      profileImagePath: '/tmp/profile.png',
      nationalIdImagePath: '/tmp/national-id.png',
      drivingLicenseImagePath: '/tmp/license.png',
      countryId: '1',
      zoneId: '2',
    ),
    expect: () => [isA<ProfileUpdateLoading>(), isA<ProfileUpdateLoaded>()],
    verify: (_) {
      final captured = verify(
        () => repository.updateProfile(
          name: captureAny(named: 'name'),
          mobile: captureAny(named: 'mobile'),
          email: captureAny(named: 'email'),
          address: captureAny(named: 'address'),
          dob: captureAny(named: 'dob'),
          bankAccountNumber: captureAny(named: 'bankAccountNumber'),
          bankName: captureAny(named: 'bankName'),
          accountName: captureAny(named: 'accountName'),
          ifscCode: captureAny(named: 'ifscCode'),
          bonusType: captureAny(named: 'bonusType'),
          bonusPercentage: captureAny(named: 'bonusPercentage'),
          bonusMinAmount: captureAny(named: 'bonusMinAmount'),
          bonusMaxAmount: captureAny(named: 'bonusMaxAmount'),
          returnBonusType: captureAny(named: 'returnBonusType'),
          returnBonusPercentage: captureAny(named: 'returnBonusPercentage'),
          returnBonusMinAmount: captureAny(named: 'returnBonusMinAmount'),
          returnBonusMaxAmount: captureAny(named: 'returnBonusMaxAmount'),
          profileImagePath: captureAny(named: 'profileImagePath'),
          nationalIdImagePath: captureAny(named: 'nationalIdImagePath'),
          drivingLicenseImagePath: captureAny(named: 'drivingLicenseImagePath'),
          countryId: captureAny(named: 'countryId'),
          zoneId: captureAny(named: 'zoneId'),
        ),
      ).captured;

      const expected = [
        'Alex Johnson',
        '1234567890',
        'alex@gmail.com',
        'Mumbai',
        '1989-08-01',
        '9000323402965',
        'Bank of Globe',
        'Alex Johnson',
        'BANGLOB',
        '1',
        '10',
        '40',
        '60',
        '1',
        '10',
        '40',
        '60',
        '/tmp/profile.png',
        '/tmp/national-id.png',
        '/tmp/license.png',
        '1',
        '2',
      ];
      printTestLog('forwarded args → expected: $expected, actual: $captured');
      expect(captured, expected);
    },
  );

  blocTest<ProfileUpdateCubit, ProfileUpdateState>(
    'updateProfile leaves untouched optional fields null',
    setUp: () {
      printTestDivider(
        'ProfileUpdateCubit.updateProfile passes null for omitted optional fields',
      );
      stubUpdate();
    },
    build: () => ProfileUpdateCubit(repository: repository),
    act: (cubit) => cubit.updateProfile(name: 'Alex', mobile: '999'),
    expect: () => [isA<ProfileUpdateLoading>(), isA<ProfileUpdateLoaded>()],
    verify: (_) {
      final captured = verify(
        () => repository.updateProfile(
          name: any(named: 'name'),
          mobile: any(named: 'mobile'),
          email: captureAny(named: 'email'),
          address: captureAny(named: 'address'),
          dob: captureAny(named: 'dob'),
          bankAccountNumber: captureAny(named: 'bankAccountNumber'),
          bankName: any(named: 'bankName'),
          accountName: any(named: 'accountName'),
          ifscCode: any(named: 'ifscCode'),
          bonusType: any(named: 'bonusType'),
          bonusPercentage: any(named: 'bonusPercentage'),
          bonusMinAmount: any(named: 'bonusMinAmount'),
          bonusMaxAmount: any(named: 'bonusMaxAmount'),
          returnBonusType: any(named: 'returnBonusType'),
          returnBonusPercentage: any(named: 'returnBonusPercentage'),
          returnBonusMinAmount: any(named: 'returnBonusMinAmount'),
          returnBonusMaxAmount: any(named: 'returnBonusMaxAmount'),
          profileImagePath: captureAny(named: 'profileImagePath'),
          nationalIdImagePath: captureAny(named: 'nationalIdImagePath'),
          drivingLicenseImagePath: captureAny(named: 'drivingLicenseImagePath'),
          countryId: captureAny(named: 'countryId'),
          zoneId: captureAny(named: 'zoneId'),
        ),
      ).captured;
      printTestLog(
        'omitted optional args → expected: all null, actual: $captured',
      );
      expect(captured.every((value) => value == null), isTrue);
    },
  );

  blocTest<ProfileUpdateCubit, ProfileUpdateState>(
    'updateProfile emits [Loading, Error] with the API message on ApiException',
    setUp: () {
      printTestDivider(
        'ProfileUpdateCubit.updateProfile emits [Loading, Error] on ApiException',
      );
      when(
        () => repository.updateProfile(
          name: any(named: 'name'),
          mobile: any(named: 'mobile'),
          email: any(named: 'email'),
          address: any(named: 'address'),
          dob: any(named: 'dob'),
          bankAccountNumber: any(named: 'bankAccountNumber'),
          bankName: any(named: 'bankName'),
          accountName: any(named: 'accountName'),
          ifscCode: any(named: 'ifscCode'),
          bonusType: any(named: 'bonusType'),
          bonusPercentage: any(named: 'bonusPercentage'),
          bonusMinAmount: any(named: 'bonusMinAmount'),
          bonusMaxAmount: any(named: 'bonusMaxAmount'),
          returnBonusType: any(named: 'returnBonusType'),
          returnBonusPercentage: any(named: 'returnBonusPercentage'),
          returnBonusMinAmount: any(named: 'returnBonusMinAmount'),
          returnBonusMaxAmount: any(named: 'returnBonusMaxAmount'),
          profileImagePath: any(named: 'profileImagePath'),
          nationalIdImagePath: any(named: 'nationalIdImagePath'),
          drivingLicenseImagePath: any(named: 'drivingLicenseImagePath'),
          countryId: any(named: 'countryId'),
          zoneId: any(named: 'zoneId'),
        ),
      ).thenThrow(const ApiException(message: 'Mobile already in use'));
    },
    build: () => ProfileUpdateCubit(repository: repository),
    act: (cubit) => cubit.updateProfile(name: 'Alex', mobile: '999'),
    expect: () => [isA<ProfileUpdateLoading>(), isA<ProfileUpdateError>()],
    verify: (cubit) {
      final message = (cubit.state as ProfileUpdateError).message;
      printTestLog(
        'message → expected: "Mobile already in use", actual: "$message"',
      );
      expect(message, 'Mobile already in use');
    },
  );

  // The non-API error path is deliberately not covered here. It calls
  // `CrashlyticsService.instance`, whose `FirebaseCrashlytics.instance` asserts
  // on plugin constants that only a real platform registration fills in — and
  // `BaseAsyncCubit.run` invokes `onUnexpectedError` *outside* its try/catch,
  // so that assert escapes the cubit instead of becoming an error state.
  // `ProfileDetailCubit`, which passes no `onUnexpectedError`, covers the
  // generic-message branch of `run` instead.
}
