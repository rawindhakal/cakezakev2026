import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/cart/cubit/cart_action_cubit.dart';

import '../../../helpers/mock_cart_repository.dart';
import '../../../helpers/test_logging.dart';

/// `CartActionCubit.addToCart`/`removeFromCart`'s SUCCESS path calls
/// `AnalyticsService.instance.logEvent(...)` right before `emit(Success)`,
/// and BOTH methods' generic (non-`ApiException`) `catch` block calls
/// `CrashlyticsService.instance.recordError(...)` — the exact same class of
/// Firebase-singleton gotcha `SignInCubit`/`ProfileUpdateCubit` already
/// document in TESTING.md. Both singletons lazily construct a real
/// `FirebaseAnalytics`/`FirebaseCrashlytics` instance and throw
/// synchronously under `flutter test` (no Firebase app initialized). Here
/// it's the same "worse" shape `ProfileUpdateCubit` hits: the Analytics
/// throw on the success path happens *inside* the method's own `try` block,
/// so it's caught by `catch (error, stack)`, which then calls
/// `CrashlyticsService.instance.recordError` — a second Firebase-singleton
/// throw with nothing left to catch it, escaping the method entirely rather
/// than landing in a state. So:
/// - The success (`CartActionSuccess`) branch of both methods is untestable.
/// - The generic-error branch of both methods is untestable (it never even
///   reaches `emit` — Crashlytics itself throws first).
/// - Only the `on ApiException catch (e)` branch of `addToCart`/
///   `removeFromCart` is covered below, since that runs and emits *before*
///   `AnalyticsService`/`CrashlyticsService` are ever touched (the exception
///   comes from `_repository.addToCart`/`removeFromCart` itself, before the
///   `AnalyticsService.instance.logEvent(...)` line is reached).
/// `clearCart()` has no Analytics/Crashlytics calls at all — fully covered.
void main() {
  late MockCartRepository repository;

  setUp(() => repository = MockCartRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is CartActionInitial', () {
    printTestDivider('CartActionCubit initial state is CartActionInitial');
    final cubit = CartActionCubit(repository: repository);
    expect(cubit.state, isA<CartActionInitial>());
    cubit.close();
  });

  blocTest<CartActionCubit, CartActionState>(
    'addToCart emits Loading then surfaces the ApiException message on failure',
    setUp: () {
      when(
        () => repository.addToCart(
          productId: any(named: 'productId'),
          productVariantId: any(named: 'productVariantId'),
          qty: any(named: 'qty'),
        ),
      ).thenThrow(const ApiException(message: 'Add failed'));
    },
    build: () => CartActionCubit(repository: repository),
    act: (cubit) =>
        cubit.addToCart(productId: '1', productVariantId: '101', qty: 1),
    expect: () {
      printTestDivider('addToCart emits Loading then surfaces ApiException message');
      return [
        isA<CartActionLoading>(),
        isA<CartActionError>()
            .having((s) => s.message, 'message', 'Add failed')
            .having((s) => s.fromRemove, 'fromRemove', isFalse),
      ];
    },
  );

  blocTest<CartActionCubit, CartActionState>(
    'removeFromCart emits Loading then surfaces the ApiException message with fromRemove: true',
    setUp: () {
      when(
        () => repository.removeFromCart(
          productId: any(named: 'productId'),
          productVariantId: any(named: 'productVariantId'),
          qty: any(named: 'qty'),
        ),
      ).thenThrow(const ApiException(message: 'Remove failed'));
    },
    build: () => CartActionCubit(repository: repository),
    act: (cubit) =>
        cubit.removeFromCart(productId: '1', productVariantId: '101'),
    expect: () {
      printTestDivider(
        'removeFromCart emits Loading then Error(fromRemove: true) on ApiException',
      );
      return [
        isA<CartActionLoading>(),
        isA<CartActionError>()
            .having((s) => s.message, 'message', 'Remove failed')
            .having((s) => s.fromRemove, 'fromRemove', isTrue),
      ];
    },
    verify: (_) {
      verify(
        () => repository.removeFromCart(
          productId: '1',
          productVariantId: '101',
          qty: 0, // qty defaults to 0 when not passed
        ),
      ).called(1);
    },
  );

  group('clearCart (no Analytics/Crashlytics calls — fully testable)', () {
    blocTest<CartActionCubit, CartActionState>(
      'emits Loading then Success(null) on success',
      setUp: () {
        when(() => repository.clearCart()).thenAnswer((_) async => 'Cleared');
      },
      build: () => CartActionCubit(repository: repository),
      act: (cubit) => cubit.clearCart(),
      expect: () {
        printTestDivider('clearCart emits Loading then Success(null)');
        return [
          isA<CartActionLoading>(),
          isA<CartActionSuccess>().having((s) => s.cart, 'cart', isNull),
        ];
      },
    );

    blocTest<CartActionCubit, CartActionState>(
      'surfaces the ApiException message on failure',
      setUp: () {
        when(
          () => repository.clearCart(),
        ).thenThrow(const ApiException(message: 'Clear failed'));
      },
      build: () => CartActionCubit(repository: repository),
      act: (cubit) => cubit.clearCart(),
      expect: () {
        printTestDivider('clearCart surfaces the ApiException message');
        return [
          isA<CartActionLoading>(),
          isA<CartActionError>().having((s) => s.message, 'message', 'Clear failed'),
        ];
      },
    );

    blocTest<CartActionCubit, CartActionState>(
      'falls back to the localized message on a generic error',
      setUp: () {
        when(() => repository.clearCart()).thenThrow(Exception('boom'));
      },
      build: () => CartActionCubit(repository: repository),
      act: (cubit) => cubit.clearCart(),
      expect: () {
        printTestDivider('clearCart falls back to localized message on generic error');
        return [
          isA<CartActionLoading>(),
          isA<CartActionError>().having((s) => s.message, 'message', isNotEmpty),
        ];
      },
    );
  });

  group('pending-flush registry (no repository call at all)', () {
    test('flushAllPending() drains registered flushers in order and clears the list', () async {
      printTestDivider('flushAllPending() drains flushers in order');
      final cubit = CartActionCubit(repository: repository);
      final order = <int>[];
      cubit.registerPendingFlush(() async => order.add(1));
      cubit.registerPendingFlush(() async => order.add(2));

      await cubit.flushAllPending();

      printTestLog('order → expected: [1, 2], actual: $order');
      expect(order, [1, 2]);

      // Second call is a no-op since the list was cleared.
      await cubit.flushAllPending();
      printTestLog('order after 2nd flush → expected: still [1, 2], actual: $order');
      expect(order, [1, 2]);
      cubit.close();
    });

    test('unregisterPendingFlush() removes a flusher before it runs', () async {
      printTestDivider('unregisterPendingFlush() removes before it runs');
      final cubit = CartActionCubit(repository: repository);
      var ran = false;
      Future<void> flusher() async => ran = true;
      cubit.registerPendingFlush(flusher);
      cubit.unregisterPendingFlush(flusher);

      await cubit.flushAllPending();

      printTestLog('ran → expected: false, actual: $ran');
      expect(ran, isFalse);
      cubit.close();
    });
  });

  test('reset() emits CartActionInitial', () async {
    printTestDivider('reset() emits CartActionInitial');
    when(
      () => repository.clearCart(),
    ).thenThrow(const ApiException(message: 'x'));
    final cubit = CartActionCubit(repository: repository);
    await cubit.clearCart(); // land in Error first

    cubit.reset();

    printTestLog('state → expected: CartActionInitial, actual: ${cubit.state}');
    expect(cubit.state, isA<CartActionInitial>());
    cubit.close();
  });
}
