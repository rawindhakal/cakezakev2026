import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/cart/models/cart_recommendations_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/cart/cart_recommendations.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('CartRecommendations.fromJson', () {
    test('parses the envelope and both blocks from a full fixture', () {
      printTestDivider(
        'CartRecommendations.fromJson parses envelope + cross_sell/upsell',
      );
      final result = CartRecommendations.fromJson(fixture());

      printTestLog('status → expected: 1, actual: ${result.status}');
      expect(result.status, 1);
      printTestLog(
        'message → expected: "Recommendations found", actual: "${result.message}"',
      );
      expect(result.message, 'Recommendations found');
      printTestLog(
        'crossSell → expected: non-null, actual: ${result.data?.crossSell}',
      );
      expect(result.data?.crossSell, isNotNull);
      printTestLog('upsell → expected: non-null, actual: ${result.data?.upsell}');
      expect(result.data?.upsell, isNotNull);
    });

    test('data is null when "data" is missing, null, or not a Map', () {
      printTestDivider('CartRecommendations.fromJson data null on bad input');
      expect(CartRecommendations.fromJson({}).data, isNull);
      expect(CartRecommendations.fromJson({'data': null}).data, isNull);
      expect(
        CartRecommendations.fromJson({'data': 'nope'}).data,
        isNull,
      );
    });

    test('toJson round trip', () {
      printTestDivider('CartRecommendations.toJson round trip');
      final result = CartRecommendations.fromJson(fixture());
      final json = result.toJson();

      printTestLog('status → expected: 1, actual: ${json['status']}');
      expect(json['status'], 1);
      printTestLog(
        'data.cross_sell present → expected: true, actual: ${json['data']['cross_sell'] != null}',
      );
      expect(json['data']['cross_sell'], isNotNull);
    });
  });

  group('CartRecommendationsData.fromJson', () {
    test(
      'crossSell/upsell each parse independently via CartRecommendationBlock.fromJson',
      () {
        printTestDivider(
          'CartRecommendationsData.fromJson crossSell/upsell parse independently',
        );
        final data = CartRecommendations.fromJson(fixture()).data!;

        printTestLog(
          'crossSell.total → expected: 12, actual: ${data.crossSell?.total}',
        );
        expect(data.crossSell?.total, 12);
        printTestLog(
          'upsell.total → expected: 6, actual: ${data.upsell?.total}',
        );
        expect(data.upsell?.total, 6);
      },
    );

    test(
      'crossSell/upsell are independently null when their own key is missing/wrong type',
      () {
        printTestDivider(
          'CartRecommendationsData.fromJson crossSell/upsell independently null',
        );
        final onlyCrossSell = CartRecommendationsData.fromJson({
          'cross_sell': {'products': [], 'total': 0, 'limit': 10, 'offset': 0},
        });
        expect(onlyCrossSell.crossSell, isNotNull);
        expect(onlyCrossSell.upsell, isNull);

        final wrongType = CartRecommendationsData.fromJson({
          'cross_sell': 'nope',
          'upsell': 123,
        });
        expect(wrongType.crossSell, isNull);
        expect(wrongType.upsell, isNull);
      },
    );
  });

  group('CartRecommendationBlock.fromJson', () {
    test('parses products/total/limit/offset off a full block', () {
      printTestDivider('CartRecommendationBlock.fromJson parses every field');
      final block = CartRecommendations.fromJson(fixture()).data!.crossSell!;

      printTestLog('products length → expected: 1, actual: ${block.products?.length}');
      expect(block.products, hasLength(1));
      printTestLog(
        'products[0].productName → expected: "Peanut Butter 500g", actual: "${block.products?[0].productName}"',
      );
      expect(block.products?[0].productName, 'Peanut Butter 500g');
      printTestLog('total → expected: 12, actual: ${block.total}');
      expect(block.total, 12);
      printTestLog('limit → expected: 10, actual: ${block.limit}');
      expect(block.limit, 10);
      printTestLog('offset → expected: 0, actual: ${block.offset}');
      expect(block.offset, 0);
    });

    test(
      'products defaults to an EMPTY LIST (not null) when "products" is '
      'missing or not a List — total/limit/offset stay null instead',
      () {
        printTestDivider(
          'CartRecommendationBlock.fromJson products defaults to [], scalars default to null',
        );
        final block = CartRecommendationBlock.fromJson({});

        printTestLog('products → expected: [], actual: ${block.products}');
        expect(block.products, isNotNull);
        expect(block.products, isEmpty);
        printTestLog('total → expected: null, actual: ${block.total}');
        expect(block.total, isNull);
        printTestLog('limit → expected: null, actual: ${block.limit}');
        expect(block.limit, isNull);
        printTestLog('offset → expected: null, actual: ${block.offset}');
        expect(block.offset, isNull);

        final wrongType = CartRecommendationBlock.fromJson({
          'products': 'not a list',
        });
        expect(wrongType.products, isNotNull);
        expect(wrongType.products, isEmpty);
      },
    );

    test('toJson round trip', () {
      printTestDivider('CartRecommendationBlock.toJson round trip');
      final block = CartRecommendations.fromJson(fixture()).data!.crossSell!;
      final json = block.toJson();

      printTestLog('total → expected: 12, actual: ${json['total']}');
      expect(json['total'], 12);
      printTestLog(
        'products[0] → expected: Map, actual: ${(json['products'] as List).first.runtimeType}',
      );
      expect((json['products'] as List).first, isA<Map>());
    });
  });
}
