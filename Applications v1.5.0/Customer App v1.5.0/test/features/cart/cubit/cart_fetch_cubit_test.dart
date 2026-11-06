import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/cart/cubit/cart_fetch_cubit.dart';
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

  test('initial state is CartFetchInitial', () {
    printTestDivider('CartFetchCubit initial state is CartFetchInitial');
    final cubit = CartFetchCubit(repository: repository);
    expect(cubit.state, isA<CartFetchInitial>());
    cubit.close();
  });

  blocTest<CartFetchCubit, CartFetchState>(
    'setCart() emits CartFetchLoaded directly, no Loading state',
    build: () => CartFetchCubit(repository: repository),
    act: (cubit) => cubit.setCart(fixtureCart()),
    expect: () {
      printTestDivider('setCart() emits CartFetchLoaded directly');
      return [isA<CartFetchLoaded>()];
    },
  );

  blocTest<CartFetchCubit, CartFetchState>(
    'fetchCart() emits Loading then Loaded on success and sends address_id when provided',
    setUp: () {
      when(
        () => repository.getCart(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          addressId: any(named: 'addressId'),
        ),
      ).thenAnswer((_) async => fixtureCart());
    },
    build: () => CartFetchCubit(repository: repository),
    act: (cubit) => cubit.fetchCart(
      latitude: '1',
      longitude: '2',
      addressId: 'addr-99',
    ),
    expect: () {
      printTestDivider('fetchCart() emits Loading then Loaded on success');
      return [
        isA<CartFetchLoading>(),
        isA<CartFetchLoaded>().having((s) => s.cart.total, 'total', 2),
      ];
    },
    verify: (_) {
      verify(
        () => repository.getCart(
          latitude: '1',
          longitude: '2',
          addressId: 'addr-99',
        ),
      ).called(1);
    },
  );

  blocTest<CartFetchCubit, CartFetchState>(
    'fetchCart() surfaces the ApiException message on failure',
    setUp: () {
      when(
        () => repository.getCart(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenThrow(const ApiException(message: 'Cart down'));
    },
    build: () => CartFetchCubit(repository: repository),
    act: (cubit) => cubit.fetchCart(),
    expect: () {
      printTestDivider('fetchCart() surfaces the ApiException message');
      return [
        isA<CartFetchLoading>(),
        isA<CartFetchError>().having((s) => s.message, 'message', 'Cart down'),
      ];
    },
  );

  blocTest<CartFetchCubit, CartFetchState>(
    'fetchCart() falls back to the localized message on a generic error',
    setUp: () {
      when(
        () => repository.getCart(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenThrow(Exception('boom'));
    },
    build: () => CartFetchCubit(repository: repository),
    act: (cubit) => cubit.fetchCart(),
    expect: () {
      printTestDivider('fetchCart() falls back to localized message on generic error');
      return [
        isA<CartFetchLoading>(),
        isA<CartFetchError>().having((s) => s.message, 'message', isNotEmpty),
      ];
    },
  );
}
