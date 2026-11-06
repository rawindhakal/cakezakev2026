import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/features/cart/repositories/cart_repository.dart';
import 'package:customer/features/products/models/addon_model.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

/// Every method here reads `SettingsHiveBox.instance.userLatitude`/
/// `userLongitude` as its fallback when explicit lat/lng args aren't passed
/// (`getCart`) or unconditionally (`getGuestCart`, `addToCart`,
/// `removeFromCart`, `getCartRecommendations`, `bulkAddToCart`) — so
/// `settingsBox` must be open via `HiveTestHelper` before any call, the same
/// requirement `auth_repository_test.dart`'s `getProfile`/`logout` groups
/// document.
void main() {
  late MockApiClient mockApiClient;
  late CartRepository repository;

  Map<String, dynamic> fixture() =>
      jsonDecode(File('test/fixtures/cart/cart.json').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, dynamic> recommendationsFixture() =>
      jsonDecode(
            File(
              'test/fixtures/cart/cart_recommendations.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = CartRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('getCart', () {
    setUp(() => HiveTestHelper.setUp(settingsBox));
    tearDown(() => HiveTestHelper.tearDown(settingsBox));

    test('hits the cart endpoint and parses a full response', () async {
      printTestDivider('getCart hits the cart endpoint and parses a full response');
      when(
        () => mockApiClient.get(
          ApiEndpoints.cart,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => fixture());

      final result = await repository.getCart(
        latitude: '1.1',
        longitude: '2.2',
        addressId: 'addr-7',
      );

      final query =
          verify(
                () => mockApiClient.get(
                  ApiEndpoints.cart,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'latitude → expected: "1.1", actual: "${query[ApiParameters.latitude]}"',
      );
      expect(query[ApiParameters.latitude], '1.1');
      printTestLog(
        'longitude → expected: "2.2", actual: "${query[ApiParameters.longitude]}"',
      );
      expect(query[ApiParameters.longitude], '2.2');
      printTestLog(
        'address_id → expected: "addr-7", actual: "${query[ApiParameters.addressId]}"',
      );
      expect(query[ApiParameters.addressId], 'addr-7');
      printTestLog('cart items → expected: 2, actual: ${result.data?.cart?.length}');
      expect(result.data?.cart, hasLength(2));
    });

    test(
      'falls back to SettingsHiveBox lat/lng when latitude/longitude are omitted',
      () async {
        printTestDivider('getCart falls back to SettingsHiveBox lat/lng');
        when(
          () => mockApiClient.get(
            ApiEndpoints.cart,
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => fixture());

        await repository.getCart();

        final query =
            verify(
                  () => mockApiClient.get(
                    ApiEndpoints.cart,
                    queryParameters: captureAny(named: 'queryParameters'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        printTestLog(
          'latitude → expected: "0" (SettingsHiveBox default), actual: "${query[ApiParameters.latitude]}"',
        );
        expect(query[ApiParameters.latitude], '0');
      },
    );

    test('an ApiException from the client rethrows as-is', () async {
      printTestDivider('getCart rethrows an ApiException as-is');
      const exception = ApiException(message: 'Cart unavailable');
      when(
        () => mockApiClient.get(
          ApiEndpoints.cart,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(exception);

      await expectLater(
        () => repository.getCart(),
        throwsA(same(exception)),
      );
    });

    test('a non-ApiException error is wrapped via ApiException.fromDioError', () async {
      printTestDivider('getCart wraps a non-ApiException error');
      when(
        () => mockApiClient.get(
          ApiEndpoints.cart,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(Exception('boom'));

      await expectLater(
        () => repository.getCart(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('getGuestCart', () {
    setUp(() => HiveTestHelper.setUp(settingsBox));
    tearDown(() => HiveTestHelper.tearDown(settingsBox));

    test('joins variantIds/quantities with commas and hits the guest cart endpoint', () async {
      printTestDivider(
        'getGuestCart joins variantIds/quantities with commas',
      );
      when(
        () => mockApiClient.get(
          ApiEndpoints.guestCart,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => fixture());

      await repository.getGuestCart(
        variantIds: ['201', '202'],
        quantities: ['2', '1'],
      );

      final query =
          verify(
                () => mockApiClient.get(
                  ApiEndpoints.guestCart,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'variant_ids → expected: "201,202", actual: "${query[ApiParameters.variantIds]}"',
      );
      expect(query[ApiParameters.variantIds], '201,202');
      printTestLog(
        'quantities → expected: "2,1", actual: "${query[ApiParameters.quantities]}"',
      );
      expect(query[ApiParameters.quantities], '2,1');
    });

    test('an ApiException from the client rethrows as-is', () async {
      printTestDivider('getGuestCart rethrows an ApiException as-is');
      const exception = ApiException(message: 'Guest cart unavailable');
      when(
        () => mockApiClient.get(
          ApiEndpoints.guestCart,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(exception);

      await expectLater(
        () => repository.getGuestCart(variantIds: [], quantities: []),
        throwsA(same(exception)),
      );
    });
  });

  group('addToCart', () {
    setUp(() => HiveTestHelper.setUp(settingsBox));
    tearDown(() => HiveTestHelper.tearDown(settingsBox));

    test('posts product_id/product_variant_id/qty and returns the full cart', () async {
      printTestDivider('addToCart posts params and returns the full cart');
      when(
        () => mockApiClient.post(
          ApiEndpoints.cartAdd,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => fixture());

      final result = await repository.addToCart(
        productId: '101',
        productVariantId: '201',
        qty: 2,
      );

      final query =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.cartAdd,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'product_id → expected: "101", actual: "${query[ApiParameters.productId]}"',
      );
      expect(query[ApiParameters.productId], '101');
      printTestLog(
        'product_variant_id → expected: "201", actual: "${query[ApiParameters.productVariantId]}"',
      );
      expect(query[ApiParameters.productVariantId], '201');
      printTestLog('qty → expected: 2, actual: ${query[ApiParameters.qty]}');
      expect(query[ApiParameters.qty], 2);
      printTestLog('result.total → expected: 2, actual: ${result.total}');
      expect(result.total, 2);
    });

    test('an ApiException from the client rethrows as-is', () async {
      printTestDivider('addToCart rethrows an ApiException as-is');
      const exception = ApiException(message: 'Add failed');
      when(
        () => mockApiClient.post(
          ApiEndpoints.cartAdd,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(exception);

      await expectLater(
        () => repository.addToCart(
          productId: '101',
          productVariantId: '201',
          qty: 1,
        ),
        throwsA(same(exception)),
      );
    });
  });

  group('removeFromCart', () {
    setUp(() => HiveTestHelper.setUp(settingsBox));
    tearDown(() => HiveTestHelper.tearDown(settingsBox));

    test('qty defaults to 0 (a full remove) when not passed', () async {
      printTestDivider('removeFromCart qty defaults to 0');
      when(
        () => mockApiClient.post(
          ApiEndpoints.cartRemove,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => fixture());

      await repository.removeFromCart(
        productId: '101',
        productVariantId: '201',
      );

      final query =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.cartRemove,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('qty → expected: 0, actual: ${query[ApiParameters.qty]}');
      expect(query[ApiParameters.qty], 0);
    });

    test('a custom qty (partial update, not a remove) is forwarded', () async {
      printTestDivider('removeFromCart forwards a custom qty');
      when(
        () => mockApiClient.post(
          ApiEndpoints.cartRemove,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => fixture());

      await repository.removeFromCart(
        productId: '101',
        productVariantId: '201',
        qty: 3,
      );

      final query =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.cartRemove,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog('qty → expected: 3, actual: ${query[ApiParameters.qty]}');
      expect(query[ApiParameters.qty], 3);
    });

    test('an ApiException from the client rethrows as-is', () async {
      printTestDivider('removeFromCart rethrows an ApiException as-is');
      const exception = ApiException(message: 'Remove failed');
      when(
        () => mockApiClient.post(
          ApiEndpoints.cartRemove,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(exception);

      await expectLater(
        () => repository.removeFromCart(
          productId: '101',
          productVariantId: '201',
        ),
        throwsA(same(exception)),
      );
    });
  });

  group('clearCart', () {
    test('posts is_remove_all=1 to the cart remove endpoint and returns the message', () async {
      printTestDivider('clearCart posts is_remove_all=1 and returns the message');
      when(
        () => mockApiClient.post(
          ApiEndpoints.cartRemove,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'message': 'Cart cleared'});

      final message = await repository.clearCart();

      final query =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.cartRemove,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'is_remove_all → expected: "1", actual: "${query[ApiParameters.isRemoveAll]}"',
      );
      expect(query[ApiParameters.isRemoveAll], '1');
      printTestLog('message → expected: "Cart cleared", actual: "$message"');
      expect(message, 'Cart cleared');
    });

    test('a missing "message" key returns an empty string, not null/crash', () async {
      printTestDivider('clearCart missing message → empty string');
      when(
        () => mockApiClient.post(
          ApiEndpoints.cartRemove,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      final message = await repository.clearCart();

      printTestLog('message → expected: "", actual: "$message"');
      expect(message, '');
    });

    test('an ApiException from the client rethrows as-is', () async {
      printTestDivider('clearCart rethrows an ApiException as-is');
      const exception = ApiException(message: 'Clear failed');
      when(
        () => mockApiClient.post(
          ApiEndpoints.cartRemove,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(exception);

      await expectLater(
        () => repository.clearCart(),
        throwsA(same(exception)),
      );
    });
  });

  group('getCartRecommendations', () {
    setUp(() => HiveTestHelper.setUp(settingsBox));
    tearDown(() => HiveTestHelper.tearDown(settingsBox));

    test('hits the recommendations endpoint with default page 1 offsets', () async {
      printTestDivider(
        'getCartRecommendations hits the recommendations endpoint with default offsets',
      );
      when(
        () => mockApiClient.get(
          ApiEndpoints.cartRecommendations,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => recommendationsFixture());

      final result = await repository.getCartRecommendations();

      final query =
          verify(
                () => mockApiClient.get(
                  ApiEndpoints.cartRecommendations,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'cross_sell_limit → expected: 10, actual: ${query[ApiParameters.crossSellLimit]}',
      );
      expect(query[ApiParameters.crossSellLimit], 10);
      printTestLog(
        'cross_sell_offset → expected: 1, actual: ${query[ApiParameters.crossSellOffset]}',
      );
      expect(query[ApiParameters.crossSellOffset], 1);
      printTestLog(
        'product_id → expected: absent, actual present: ${query.containsKey(ApiParameters.productId)}',
      );
      expect(query.containsKey(ApiParameters.productId), isFalse);
      printTestLog(
        'crossSell.products length → expected: 1, actual: ${result.data?.crossSell?.products?.length}',
      );
      expect(result.data?.crossSell?.products, hasLength(1));
    });

    test('a non-null productId is forwarded (product-detail-screen call)', () async {
      printTestDivider('getCartRecommendations forwards a non-null productId');
      when(
        () => mockApiClient.get(
          ApiEndpoints.cartRecommendations,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => recommendationsFixture());

      await repository.getCartRecommendations(productId: '101');

      final query =
          verify(
                () => mockApiClient.get(
                  ApiEndpoints.cartRecommendations,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'product_id → expected: "101", actual: "${query[ApiParameters.productId]}"',
      );
      expect(query[ApiParameters.productId], '101');
    });

    test('a custom page forwards the right limit/offset for both blocks', () async {
      printTestDivider('getCartRecommendations forwards custom limit/offset');
      when(
        () => mockApiClient.get(
          ApiEndpoints.cartRecommendations,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => recommendationsFixture());

      await repository.getCartRecommendations(
        crossSellLimit: 5,
        crossSellOffset: 15,
        upsellLimit: 8,
        upsellOffset: 24,
      );

      final query =
          verify(
                () => mockApiClient.get(
                  ApiEndpoints.cartRecommendations,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(query[ApiParameters.crossSellLimit], 5);
      expect(query[ApiParameters.crossSellOffset], 15);
      expect(query[ApiParameters.upsellLimit], 8);
      expect(query[ApiParameters.upsellOffset], 24);
    });

    test('an ApiException from the client rethrows as-is', () async {
      printTestDivider('getCartRecommendations rethrows an ApiException as-is');
      const exception = ApiException(message: 'Recommendations unavailable');
      when(
        () => mockApiClient.get(
          ApiEndpoints.cartRecommendations,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(exception);

      await expectLater(
        () => repository.getCartRecommendations(),
        throwsA(same(exception)),
      );
    });
  });

  group('bulkAddToCart', () {
    setUp(() => HiveTestHelper.setUp(settingsBox));
    tearDown(() => HiveTestHelper.tearDown(settingsBox));

    test('joins each list with commas and returns the response message', () async {
      printTestDivider('bulkAddToCart joins each list with commas');
      when(
        () => mockApiClient.post(
          ApiEndpoints.guestCartBulkAddToCartWhileLogin,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => {'status': 1, 'message': 'Merged'});

      final message = await repository.bulkAddToCart(
        quickItems: const [
          BulkCartItem(variantId: '1', qty: 1),
          BulkCartItem(variantId: '2', qty: 3),
        ],
        ecommerceItems: const [BulkCartItem(variantId: '9', qty: 2)],
      );

      final query =
          verify(
                () => mockApiClient.post(
                  ApiEndpoints.guestCartBulkAddToCartWhileLogin,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'quick_variant_ids → expected: "1,2", actual: "${query[ApiParameters.quickVariantIds]}"',
      );
      expect(query[ApiParameters.quickVariantIds], '1,2');
      printTestLog(
        'ecommerce_variant_ids → expected: "9", actual: "${query[ApiParameters.ecommerceVariantIds]}"',
      );
      expect(query[ApiParameters.ecommerceVariantIds], '9');
      printTestLog(
        'quick_quantities → expected: "1,3", actual: "${query[ApiParameters.quickQuantities]}"',
      );
      expect(query[ApiParameters.quickQuantities], '1,3');
      printTestLog('message → expected: "Merged", actual: "$message"');
      expect(message, 'Merged');
    });

    test(
      'a channel with an add-on line goes as *_items in the body; the other keeps CSV',
      () async {
        printTestDivider('bulkAddToCart sends add-on basket as quick_items');
        when(
          () => mockApiClient.post(
            ApiEndpoints.guestCartBulkAddToCartWhileLogin,
            queryParameters: any(named: 'queryParameters'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => {'status': 1, 'message': 'Merged'});

        await repository.bulkAddToCart(
          quickItems: const [
            BulkCartItem(variantId: '31', qty: 2),
            BulkCartItem(
              variantId: '12',
              qty: 1,
              addons: [
                AddonSelection(id: 1, qty: 1),
                AddonSelection(id: 9, qty: 2),
              ],
            ),
          ],
          ecommerceItems: const [BulkCartItem(variantId: '77', qty: 1)],
        );

        final captured = verify(
          () => mockApiClient.post(
            ApiEndpoints.guestCartBulkAddToCartWhileLogin,
            queryParameters: captureAny(named: 'queryParameters'),
            data: captureAny(named: 'data'),
          ),
        ).captured;
        final query = captured[0] as Map<String, dynamic>;
        final body = captured[1] as Map<String, dynamic>;
        printTestLog(
          'quick CSV → expected: absent, actual: ${query[ApiParameters.quickVariantIds]}',
        );
        expect(query.containsKey(ApiParameters.quickVariantIds), isFalse);
        expect(query[ApiParameters.ecommerceVariantIds], '77');
        printTestLog('quick_items → actual: ${body[ApiParameters.quickItems]}');
        expect(body[ApiParameters.quickItems], [
          {'variant_id': 31, 'qty': 2},
          {
            'variant_id': 12,
            'qty': 1,
            'addons': [1, 9, 9],
          },
        ]);
        expect(body.containsKey(ApiParameters.ecommerceItems), isFalse);
      },
    );

    test('a missing "message" key returns an empty string, not null/crash', () async {
      printTestDivider('bulkAddToCart missing message → empty string');
      when(
        () => mockApiClient.post(
          ApiEndpoints.guestCartBulkAddToCartWhileLogin,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => {'status': 1});

      final message = await repository.bulkAddToCart();

      printTestLog('message → expected: "", actual: "$message"');
      expect(message, '');
    });

    test('an ApiException from the client rethrows as-is', () async {
      printTestDivider('bulkAddToCart rethrows an ApiException as-is');
      const exception = ApiException(message: 'Merge failed');
      when(
        () => mockApiClient.post(
          ApiEndpoints.guestCartBulkAddToCartWhileLogin,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(exception);

      await expectLater(
        () => repository.bulkAddToCart(
          quickItems: const [BulkCartItem(variantId: '1', qty: 1)],
        ),
        throwsA(same(exception)),
      );
    });
  });
}
