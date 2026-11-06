import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/wallet/cubit/withdrawal_cubit.dart';

import '../../../helpers/mock_wallet_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockWalletRepository repository;

  setUp(() => repository = MockWalletRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('submit emits [Loading, Loaded] and sends amount/message', () async {
    printTestDivider(
      'WithdrawalCubit submit emits [Loading, Loaded] and sends amount/message',
    );
    when(
      () => repository.addWithdrawalRequest(
        amount: any(named: 'amount'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async {});
    final cubit = WithdrawalCubit(repository: repository);

    await cubit.submit(amount: '500', message: 'Need cash');

    verify(
      () => repository.addWithdrawalRequest(
        amount: '500',
        message: 'Need cash',
      ),
    ).called(1);
    printTestLog(
      'state → expected: WithdrawalLoaded, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<WithdrawalLoaded>());
    await cubit.close();
  });

  blocTest<WithdrawalCubit, WithdrawalState>(
    'submit emits [Loading, Loaded] in order on success',
    setUp: () {
      when(
        () => repository.addWithdrawalRequest(
          amount: any(named: 'amount'),
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) async {});
    },
    build: () => WithdrawalCubit(repository: repository),
    act: (cubit) => cubit.submit(amount: '500'),
    expect: () => [isA<WithdrawalLoading>(), isA<WithdrawalLoaded>()],
  );

  blocTest<WithdrawalCubit, WithdrawalState>(
    'submit emits [Loading, Error] with the API message on failure',
    setUp: () {
      when(
        () => repository.addWithdrawalRequest(
          amount: any(named: 'amount'),
          message: any(named: 'message'),
        ),
      ).thenThrow(const ApiException(message: 'Withdrawal amount exceeds balance'));
    },
    build: () => WithdrawalCubit(repository: repository),
    act: (cubit) => cubit.submit(amount: '99999'),
    expect: () => [
      isA<WithdrawalLoading>(),
      isA<WithdrawalError>().having(
        (s) => s.message,
        'message',
        'Withdrawal amount exceeds balance',
      ),
    ],
  );

  test('reset returns the cubit to its initial state', () async {
    printTestDivider('WithdrawalCubit reset returns the cubit to its initial state');
    when(
      () => repository.addWithdrawalRequest(
        amount: any(named: 'amount'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async {});
    final cubit = WithdrawalCubit(repository: repository);
    await cubit.submit(amount: '500');

    cubit.reset();

    printTestLog(
      'state → expected: WithdrawalInitial, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<WithdrawalInitial>());
    await cubit.close();
  });
}
