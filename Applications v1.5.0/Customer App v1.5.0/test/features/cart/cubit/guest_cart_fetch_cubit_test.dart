import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/cart/cubit/guest_cart_fetch_cubit.dart';
import 'package:customer/features/cart/models/cart_model.dart';

import '../../../helpers/mock_cart_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCartRepository repository;

  Cart fixtureCart() => Cart.fromJson(
    jsonDecode(File('test/fixtures/cart/cart.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  setUp(() => repository = MockCartRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is GuestCartInitial', () {
    printTestDivider('GuestCartFetchCubit initial state is GuestCartInitial');
    final cubit = GuestCartFetchCubit(repository: repository);
    expect(cubit.state, isA<GuestCartInitial>());
    cubit.close();
  });

  blocTest<GuestCartFetchCubit, GuestCartState>(
    'an empty variantIds list resets straight to GuestCartInitial, no API call',
    build: () => GuestCartFetchCubit(repository: repository),
    act: (cubit) => cubit.fetchGuestCart(variantIds: [], quantities: []),
    expect: () {
      printTestDivider('fetchGuestCart empty variantIds resets to Initial, no API call');
      return [isA<GuestCartInitial>()];
    },
    verify: (_) {
      verifyNever(
        () => repository.getGuestCart(
          variantIds: any(named: 'variantIds'),
          quantities: any(named: 'quantities'),
        ),
      );
    },
  );

  blocTest<GuestCartFetchCubit, GuestCartState>(
    'emits Loading then Loaded on success (non-silent)',
    setUp: () {
      when(
        () => repository.getGuestCart(
          variantIds: any(named: 'variantIds'),
          quantities: any(named: 'quantities'),
        ),
      ).thenAnswer((_) async => fixtureCart());
    },
    build: () => GuestCartFetchCubit(repository: repository),
    act: (cubit) => cubit.fetchGuestCart(variantIds: ['201'], quantities: ['2']),
    expect: () {
      printTestDivider('fetchGuestCart emits Loading then Loaded (non-silent)');
      return [isA<GuestCartLoading>(), isA<GuestCartLoaded>()];
    },
    verify: (_) {
      verify(
        () => repository.getGuestCart(variantIds: ['201'], quantities: ['2']),
      ).called(1);
    },
  );

  blocTest<GuestCartFetchCubit, GuestCartState>(
    'silent: true skips Loading once already Loaded, avoiding a UI flicker',
    setUp: () {
      when(
        () => repository.getGuestCart(
          variantIds: any(named: 'variantIds'),
          quantities: any(named: 'quantities'),
        ),
      ).thenAnswer((_) async => fixtureCart());
    },
    build: () => GuestCartFetchCubit(repository: repository),
    seed: () => GuestCartLoaded(fixtureCart()), // pretend already loaded
    act: (cubit) => cubit.fetchGuestCart(
      variantIds: ['201'],
      quantities: ['2'],
      silent: true,
    ),
    expect: () {
      printTestDivider('fetchGuestCart silent:true skips Loading once already Loaded');
      return [isA<GuestCartLoaded>()]; // no Loading in between
    },
  );

  blocTest<GuestCartFetchCubit, GuestCartState>(
    'silent: true still shows Loading when not yet Loaded',
    setUp: () {
      when(
        () => repository.getGuestCart(
          variantIds: any(named: 'variantIds'),
          quantities: any(named: 'quantities'),
        ),
      ).thenAnswer((_) async => fixtureCart());
    },
    build: () => GuestCartFetchCubit(repository: repository), // state is Initial
    act: (cubit) => cubit.fetchGuestCart(
      variantIds: ['201'],
      quantities: ['1'],
      silent: true,
    ),
    expect: () {
      printTestDivider('fetchGuestCart silent:true still shows Loading pre-Loaded');
      return [isA<GuestCartLoading>(), isA<GuestCartLoaded>()];
    },
  );

  blocTest<GuestCartFetchCubit, GuestCartState>(
    'surfaces the ApiException message on failure',
    setUp: () {
      when(
        () => repository.getGuestCart(
          variantIds: any(named: 'variantIds'),
          quantities: any(named: 'quantities'),
        ),
      ).thenThrow(const ApiException(message: 'Guest cart down'));
    },
    build: () => GuestCartFetchCubit(repository: repository),
    act: (cubit) => cubit.fetchGuestCart(variantIds: ['201'], quantities: ['1']),
    expect: () {
      printTestDivider('fetchGuestCart surfaces the ApiException message');
      return [
        isA<GuestCartLoading>(),
        isA<GuestCartError>().having((s) => s.message, 'message', 'Guest cart down'),
      ];
    },
  );

  blocTest<GuestCartFetchCubit, GuestCartState>(
    'falls back to the localized message on a generic error',
    setUp: () {
      when(
        () => repository.getGuestCart(
          variantIds: any(named: 'variantIds'),
          quantities: any(named: 'quantities'),
        ),
      ).thenThrow(Exception('boom'));
    },
    build: () => GuestCartFetchCubit(repository: repository),
    act: (cubit) => cubit.fetchGuestCart(variantIds: ['201'], quantities: ['1']),
    expect: () {
      printTestDivider('fetchGuestCart falls back to localized message on generic error');
      return [isA<GuestCartLoading>(), isA<GuestCartError>()];
    },
  );
}
