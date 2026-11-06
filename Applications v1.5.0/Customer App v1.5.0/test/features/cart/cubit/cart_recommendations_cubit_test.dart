import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/cart/cubit/cart_recommendations_cubit.dart';
import 'package:customer/features/cart/models/cart_recommendations_model.dart';

import '../../../helpers/mock_cart_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCartRepository repository;

  CartRecommendations fixture() => CartRecommendations.fromJson(
    jsonDecode(
          File(
            'test/fixtures/cart/cart_recommendations.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>,
  );

  void stubGetRecommendations(
    Future<CartRecommendations> Function(Invocation) answer,
  ) {
    when(
      () => repository.getCartRecommendations(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        productId: any(named: 'productId'),
        crossSellLimit: any(named: 'crossSellLimit'),
        crossSellOffset: any(named: 'crossSellOffset'),
        upsellLimit: any(named: 'upsellLimit'),
        upsellOffset: any(named: 'upsellOffset'),
      ),
    ).thenAnswer(answer);
  }

  setUp(() => repository = MockCartRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('initial state is CartRecommendationsInitial', () {
    printTestDivider(
      'CartRecommendationsCubit initial state is CartRecommendationsInitial',
    );
    final cubit = CartRecommendationsCubit(repository: repository);
    expect(cubit.state, isA<CartRecommendationsInitial>());
    cubit.close();
  });

  group('fetchRecommendations', () {
    blocTest<CartRecommendationsCubit, CartRecommendationsState>(
      'emits Loading then Loaded on success, page 1 offsets',
      setUp: () => stubGetRecommendations((_) async => fixture()),
      build: () => CartRecommendationsCubit(repository: repository),
      act: (cubit) => cubit.fetchRecommendations(productId: '101'),
      expect: () {
        printTestDivider(
          'fetchRecommendations emits Loading then Loaded, page 1 offsets',
        );
        return [
          isA<CartRecommendationsLoading>(),
          isA<CartRecommendationsLoaded>(),
        ];
      },
      verify: (_) {
        verify(
          () => repository.getCartRecommendations(
            latitude: null,
            longitude: null,
            productId: '101',
            crossSellLimit: 10,
            crossSellOffset: 0,
            upsellLimit: 10,
            upsellOffset: 0,
          ),
        ).called(1);
      },
    );

    blocTest<CartRecommendationsCubit, CartRecommendationsState>(
      'surfaces the ApiException message on failure',
      setUp: () => stubGetRecommendations(
        (_) async => throw const ApiException(message: 'Recs down'),
      ),
      build: () => CartRecommendationsCubit(repository: repository),
      act: (cubit) => cubit.fetchRecommendations(),
      expect: () {
        printTestDivider('fetchRecommendations surfaces the ApiException message');
        return [
          isA<CartRecommendationsLoading>(),
          isA<CartRecommendationsError>().having((s) => s.message, 'message', 'Recs down'),
        ];
      },
    );

    blocTest<CartRecommendationsCubit, CartRecommendationsState>(
      'falls back to the localized message on a generic error',
      setUp: () => stubGetRecommendations((_) async => throw Exception('boom')),
      build: () => CartRecommendationsCubit(repository: repository),
      act: (cubit) => cubit.fetchRecommendations(),
      expect: () {
        printTestDivider('fetchRecommendations falls back to localized message');
        return [isA<CartRecommendationsLoading>(), isA<CartRecommendationsError>()];
      },
    );
  });

  group('CartRecommendationsLoaded.hasMoreCrossSell / hasMoreUpsell', () {
    test('true only when loaded products length is less than total', () {
      printTestDivider('hasMoreCrossSell/hasMoreUpsell true when products < total');
      final loaded = CartRecommendationsLoaded(fixture());
      // fixture: cross_sell total 12 with 1 product loaded, upsell total 6 with 1 loaded.
      printTestLog('hasMoreCrossSell → expected: true, actual: ${loaded.hasMoreCrossSell}');
      expect(loaded.hasMoreCrossSell, isTrue);
      printTestLog('hasMoreUpsell → expected: true, actual: ${loaded.hasMoreUpsell}');
      expect(loaded.hasMoreUpsell, isTrue);
    });

    test('false when total is null (no more to load)', () {
      printTestDivider('hasMoreCrossSell/hasMoreUpsell false when total is null');
      final recs = CartRecommendations.fromJson({
        'status': 1,
        'data': {
          'cross_sell': {'products': [], 'total': null},
          'upsell': {'products': [], 'total': null},
        },
      });
      final loaded = CartRecommendationsLoaded(recs);
      expect(loaded.hasMoreCrossSell, isFalse);
      expect(loaded.hasMoreUpsell, isFalse);
    });
  });

  group('loadMoreCrossSell', () {
    test('is a no-op when state is not CartRecommendationsLoaded', () async {
      printTestDivider('loadMoreCrossSell no-op when state is not Loaded');
      final cubit = CartRecommendationsCubit(repository: repository);

      await cubit.loadMoreCrossSell();

      verifyNever(
        () => repository.getCartRecommendations(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          productId: any(named: 'productId'),
          crossSellLimit: any(named: 'crossSellLimit'),
          crossSellOffset: any(named: 'crossSellOffset'),
          upsellLimit: any(named: 'upsellLimit'),
          upsellOffset: any(named: 'upsellOffset'),
        ),
      );
      cubit.close();
    });

    test('is a no-op when hasMoreCrossSell is false', () async {
      printTestDivider('loadMoreCrossSell no-op when hasMoreCrossSell is false');
      stubGetRecommendations((_) async => CartRecommendations.fromJson({
        'status': 1,
        'data': {
          'cross_sell': {
            'products': [
              {'id': 1},
            ],
            'total': 1,
          },
          'upsell': {'products': [], 'total': 0},
        },
      }));
      final cubit = CartRecommendationsCubit(repository: repository);
      await cubit.fetchRecommendations();
      clearInteractions(repository);

      await cubit.loadMoreCrossSell();

      verifyNever(
        () => repository.getCartRecommendations(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          productId: any(named: 'productId'),
          crossSellLimit: any(named: 'crossSellLimit'),
          crossSellOffset: any(named: 'crossSellOffset'),
          upsellLimit: any(named: 'upsellLimit'),
          upsellOffset: any(named: 'upsellOffset'),
        ),
      );
      cubit.close();
    });

    test(
      'fetches the next page, appends de-duped products, and advances the '
      'cross-sell offset independently of upsell',
      () async {
        printTestDivider(
          'loadMoreCrossSell appends de-duped products, advances cross-sell offset only',
        );
        stubGetRecommendations((_) async => fixture());
        final cubit = CartRecommendationsCubit(repository: repository);
        await cubit.fetchRecommendations();
        clearInteractions(repository);

        // Page 2: one duplicate (id 301, already loaded) + one new (id 303).
        stubGetRecommendations(
          (_) async => CartRecommendations.fromJson({
            'status': 1,
            'data': {
              'cross_sell': {
                'products': [
                  {'id': 301, 'name': 'dup'},
                  {'id': 303, 'name': 'new item'},
                ],
                'total': 12,
              },
              'upsell': {'products': [], 'total': 6},
            },
          }),
        );

        await cubit.loadMoreCrossSell();

        final loaded = cubit.state as CartRecommendationsLoaded;
        final ids = loaded.recommendations.data?.crossSell?.products
            ?.map((p) => p.id)
            .toList();
        printTestLog(
          'crossSell product ids → expected: [301, 303] (no dupe), actual: $ids',
        );
        expect(ids, [301, 303]);

        verify(
          () => repository.getCartRecommendations(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            productId: any(named: 'productId'),
            crossSellLimit: 10,
            crossSellOffset: 10, // page 2 → (2-1)*10
            upsellLimit: 10,
            upsellOffset: 0, // upsell page unchanged
          ),
        ).called(1);
        cubit.close();
      },
    );

    test('surfaces the ApiException message on failure', () async {
      printTestDivider('loadMoreCrossSell surfaces the ApiException message');
      stubGetRecommendations((_) async => fixture());
      final cubit = CartRecommendationsCubit(repository: repository);
      await cubit.fetchRecommendations();
      stubGetRecommendations(
        (_) async => throw const ApiException(message: 'Load more failed'),
      );

      await cubit.loadMoreCrossSell();

      final state = cubit.state as CartRecommendationsError;
      expect(state.message, 'Load more failed');
      cubit.close();
    });
  });

  group('loadMoreUpsell', () {
    test('is a no-op when state is not CartRecommendationsLoaded', () async {
      printTestDivider('loadMoreUpsell no-op when state is not Loaded');
      final cubit = CartRecommendationsCubit(repository: repository);

      await cubit.loadMoreUpsell();

      verifyNever(
        () => repository.getCartRecommendations(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          productId: any(named: 'productId'),
          crossSellLimit: any(named: 'crossSellLimit'),
          crossSellOffset: any(named: 'crossSellOffset'),
          upsellLimit: any(named: 'upsellLimit'),
          upsellOffset: any(named: 'upsellOffset'),
        ),
      );
      cubit.close();
    });

    test(
      'fetches the next page, appends de-duped products, and advances the '
      'upsell offset independently of cross-sell',
      () async {
        printTestDivider(
          'loadMoreUpsell appends de-duped products, advances upsell offset only',
        );
        stubGetRecommendations((_) async => fixture());
        final cubit = CartRecommendationsCubit(repository: repository);
        await cubit.fetchRecommendations();
        clearInteractions(repository);

        stubGetRecommendations(
          (_) async => CartRecommendations.fromJson({
            'status': 1,
            'data': {
              'cross_sell': {'products': [], 'total': 12},
              'upsell': {
                'products': [
                  {'id': 302, 'name': 'dup'},
                  {'id': 304, 'name': 'new item'},
                ],
                'total': 6,
              },
            },
          }),
        );

        await cubit.loadMoreUpsell();

        final loaded = cubit.state as CartRecommendationsLoaded;
        final ids = loaded.recommendations.data?.upsell?.products
            ?.map((p) => p.id)
            .toList();
        printTestLog(
          'upsell product ids → expected: [302, 304] (no dupe), actual: $ids',
        );
        expect(ids, [302, 304]);

        verify(
          () => repository.getCartRecommendations(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            productId: any(named: 'productId'),
            crossSellLimit: 10,
            crossSellOffset: 0, // cross-sell page unchanged
            upsellLimit: 10,
            upsellOffset: 10, // page 2 → (2-1)*10
          ),
        ).called(1);
        cubit.close();
      },
    );
  });
}
