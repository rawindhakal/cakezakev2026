import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/auth/cubit/add_fcm_token_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/update_fcm_token_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('AddFcmTokenCubit', () {
    blocTest<AddFcmTokenCubit, AddFcmTokenState>(
      'emits [Loading, Loaded] and forwards the token and platform',
      setUp: () {
        printTestDivider(
          'AddFcmTokenCubit emits [Loading, Loaded] and forwards the token and platform',
        );
        when(
          () => repository.addFcmToken(
            fcmToken: any(named: 'fcmToken'),
            platform: any(named: 'platform'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => AddFcmTokenCubit(repository: repository),
      act: (cubit) => cubit.addFcmToken(fcmToken: 'fcm1', platform: 'android'),
      expect: () => [isA<AddFcmTokenLoading>(), isA<AddFcmTokenLoaded>()],
      verify: (_) {
        verify(
          () => repository.addFcmToken(fcmToken: 'fcm1', platform: 'android'),
        ).called(1);
      },
    );

    blocTest<AddFcmTokenCubit, AddFcmTokenState>(
      'emits [Loading, Error] carrying the API message on failure',
      setUp: () {
        printTestDivider(
          'AddFcmTokenCubit emits [Loading, Error] carrying the API message on failure',
        );
        when(
          () => repository.addFcmToken(
            fcmToken: any(named: 'fcmToken'),
            platform: any(named: 'platform'),
          ),
        ).thenThrow(const ApiException(message: 'Token rejected'));
      },
      build: () => AddFcmTokenCubit(repository: repository),
      act: (cubit) => cubit.addFcmToken(fcmToken: 'fcm1', platform: 'android'),
      expect: () => [
        isA<AddFcmTokenLoading>(),
        isA<AddFcmTokenError>().having(
          (s) => s.message,
          'message',
          'Token rejected',
        ),
      ],
    );
  });

  group('UpdateFcmTokenCubit', () {
    blocTest<UpdateFcmTokenCubit, UpdateFcmTokenState>(
      'emits [Loading, Loaded] and forwards token, platform and language',
      setUp: () {
        printTestDivider(
          'UpdateFcmTokenCubit emits [Loading, Loaded] and forwards token, platform and language',
        );
        when(
          () => repository.updateFcmToken(
            fcmToken: any(named: 'fcmToken'),
            platform: any(named: 'platform'),
            languageId: any(named: 'languageId'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => UpdateFcmTokenCubit(repository: repository),
      act: (cubit) => cubit.updateFcmToken(
        fcmToken: 'fcm2',
        platform: 'ios',
        languageId: '3',
      ),
      expect: () => [isA<UpdateFcmTokenLoading>(), isA<UpdateFcmTokenLoaded>()],
      verify: (_) {
        verify(
          () => repository.updateFcmToken(
            fcmToken: 'fcm2',
            platform: 'ios',
            languageId: '3',
          ),
        ).called(1);
      },
    );

    blocTest<UpdateFcmTokenCubit, UpdateFcmTokenState>(
      'emits [Loading, Error] carrying the API message on failure',
      setUp: () {
        printTestDivider(
          'UpdateFcmTokenCubit emits [Loading, Error] carrying the API message on failure',
        );
        when(
          () => repository.updateFcmToken(
            fcmToken: any(named: 'fcmToken'),
            platform: any(named: 'platform'),
            languageId: any(named: 'languageId'),
          ),
        ).thenThrow(const ApiException(message: 'Update failed'));
      },
      build: () => UpdateFcmTokenCubit(repository: repository),
      act: (cubit) => cubit.updateFcmToken(
        fcmToken: 'fcm2',
        platform: 'ios',
        languageId: '3',
      ),
      expect: () => [
        isA<UpdateFcmTokenLoading>(),
        isA<UpdateFcmTokenError>().having(
          (s) => s.message,
          'message',
          'Update failed',
        ),
      ],
    );
  });
}
