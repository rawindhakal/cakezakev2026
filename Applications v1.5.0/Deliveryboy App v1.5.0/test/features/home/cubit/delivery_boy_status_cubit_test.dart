import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/home/cubit/delivery_boy_status_cubit.dart';

import '../../../helpers/mock_auth_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockAuthRepository repository;

  // Server codes: 1 = online, 3 = offline, 4 = blocked.
  const online = 1;
  const offline = 3;
  const blocked = 4;

  setUp(() => repository = MockAuthRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void stubStatus(int status, {String? remark}) {
    when(
      () => repository.getDeliveryBoyStatus(),
    ).thenAnswer((_) async => (status: status, remark: remark));
  }

  /// Puts the cubit in Loaded with [status] the way the screen does — via a
  /// real checkStatus() call — so toggleOnline sees a genuine prior state.
  Future<void> loadStatus(DeliveryBoyStatusCubit cubit, int status) async {
    stubStatus(status);
    await cubit.checkStatus();
  }

  group('checkStatus', () {
    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'emits [Loading, Loaded] with the status and remark',
      setUp: () {
        printTestDivider('checkStatus emits [Loading, Loaded] with the status and remark');
        stubStatus(blocked, remark: 'Documents expired');
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) => cubit.checkStatus(),
      expect: () => [
        isA<DeliveryBoyStatusLoading>(),
        isA<DeliveryBoyStatusLoaded>()
            .having((s) => s.data.status, 'status', blocked)
            .having((s) => s.data.remark, 'remark', 'Documents expired'),
      ],
    );

    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'emits [Loading, Error] carrying the API message on failure',
      setUp: () {
        printTestDivider(
          'checkStatus emits [Loading, Error] carrying the API message on failure',
        );
        when(
          () => repository.getDeliveryBoyStatus(),
        ).thenThrow(const ApiException(message: 'Status unavailable'));
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) => cubit.checkStatus(),
      expect: () => [
        isA<DeliveryBoyStatusLoading>(),
        isA<DeliveryBoyStatusError>().having(
          (s) => s.message,
          'message',
          'Status unavailable',
        ),
      ],
    );
  });

  group('toggleOnline', () {
    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'switches online to offline and persists the change',
      setUp: () {
        printTestDivider('toggleOnline switches online to offline and persists the change');
        when(
          () => repository.updateDeliveryBoyStatus(status: any(named: 'status')),
        ).thenAnswer((_) async {});
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) async {
        await loadStatus(cubit, online);
        await cubit.toggleOnline();
      },
      skip: 2, // the checkStatus Loading/Loaded pair
      expect: () => [
        isA<DeliveryBoyStatusLoaded>().having((s) => s.data.status, 'status', offline),
      ],
      verify: (_) => verify(
        () => repository.updateDeliveryBoyStatus(status: offline),
      ).called(1),
    );

    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'switches offline back to online',
      setUp: () {
        printTestDivider('toggleOnline switches offline back to online');
        when(
          () => repository.updateDeliveryBoyStatus(status: any(named: 'status')),
        ).thenAnswer((_) async {});
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) async {
        await loadStatus(cubit, offline);
        await cubit.toggleOnline();
      },
      skip: 2,
      expect: () => [
        isA<DeliveryBoyStatusLoaded>().having((s) => s.data.status, 'status', online),
      ],
      verify: (_) => verify(
        () => repository.updateDeliveryBoyStatus(status: online),
      ).called(1),
    );

    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'does nothing for a blocked account',
      setUp: () {
        printTestDivider('toggleOnline does nothing for a blocked account');
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) async {
        await loadStatus(cubit, blocked);
        await cubit.toggleOnline();
      },
      skip: 2,
      expect: () => <DeliveryBoyStatusState>[],
      verify: (_) => verifyNever(
        () => repository.updateDeliveryBoyStatus(status: any(named: 'status')),
      ),
    );

    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'does nothing before a status has been loaded',
      setUp: () {
        printTestDivider('toggleOnline does nothing before a status has been loaded');
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) => cubit.toggleOnline(),
      expect: () => <DeliveryBoyStatusState>[],
      verify: (_) => verifyNever(
        () => repository.updateDeliveryBoyStatus(status: any(named: 'status')),
      ),
    );

    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'surfaces the API error then rolls the status back',
      setUp: () {
        printTestDivider('toggleOnline surfaces the API error then rolls the status back');
        when(
          () => repository.updateDeliveryBoyStatus(status: any(named: 'status')),
        ).thenThrow(const ApiException(message: 'Could not update status'));
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) async {
        await loadStatus(cubit, online);
        await cubit.toggleOnline();
      },
      skip: 2,
      // Optimistic switch first, then the error, then back to where it started.
      expect: () => [
        isA<DeliveryBoyStatusLoaded>().having((s) => s.data.status, 'status', offline),
        isA<DeliveryBoyStatusError>().having(
          (s) => s.message,
          'message',
          'Could not update status',
        ),
        isA<DeliveryBoyStatusLoaded>().having((s) => s.data.status, 'status', online),
      ],
    );

    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'rolls back silently on a non-API error',
      setUp: () {
        printTestDivider('toggleOnline rolls back silently on a non-API error');
        when(
          () => repository.updateDeliveryBoyStatus(status: any(named: 'status')),
        ).thenThrow(Exception('unexpected'));
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) async {
        await loadStatus(cubit, online);
        await cubit.toggleOnline();
      },
      skip: 2,
      // No error state here — an unexpected failure just restores the status.
      expect: () => [
        isA<DeliveryBoyStatusLoaded>().having((s) => s.data.status, 'status', offline),
        isA<DeliveryBoyStatusLoaded>().having((s) => s.data.status, 'status', online),
      ],
    );

    blocTest<DeliveryBoyStatusCubit, DeliveryBoyStatusState>(
      'keeps the remark when toggling',
      setUp: () {
        printTestDivider('toggleOnline keeps the remark when toggling');
        when(
          () => repository.getDeliveryBoyStatus(),
        ).thenAnswer((_) async => (status: online, remark: 'On probation'));
        when(
          () => repository.updateDeliveryBoyStatus(status: any(named: 'status')),
        ).thenAnswer((_) async {});
      },
      build: () => DeliveryBoyStatusCubit(repository: repository),
      act: (cubit) async {
        await cubit.checkStatus();
        await cubit.toggleOnline();
      },
      skip: 2,
      expect: () => [
        isA<DeliveryBoyStatusLoaded>().having(
          (s) => s.data.remark,
          'remark',
          'On probation',
        ),
      ],
    );
  });
}
