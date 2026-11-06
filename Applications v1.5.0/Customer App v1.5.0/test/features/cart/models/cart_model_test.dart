import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/cart/models/cart_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(File('test/fixtures/cart/cart.json').readAsStringSync())
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('Cart.fromJson', () {
    test('parses the envelope and every field of a full fixture', () {
      printTestDivider('Cart.fromJson parses the envelope and data block');
      final cart = Cart.fromJson(fixture());

      printTestLog('status → expected: 1, actual: ${cart.status}');
      expect(cart.status, 1);
      printTestLog(
        'message → expected: "Cart found", actual: "${cart.message}"',
      );
      expect(cart.message, 'Cart found');
      printTestLog('total → expected: 2, actual: ${cart.total}');
      expect(cart.total, 2);
      printTestLog('data → expected: non-null, actual: ${cart.data}');
      expect(cart.data, isNotNull);
    });

    test(
      'status/total are bare ints (parseInt), tolerating a stringified value too',
      () {
        printTestDivider(
          'Cart.fromJson status/total tolerate a stringified value',
        );
        final cart = Cart.fromJson({
          'status': '1',
          'total': '5',
          'message': 'ok',
        });

        printTestLog('status → expected: 1, actual: ${cart.status}');
        expect(cart.status, 1);
        printTestLog('total → expected: 5, actual: ${cart.total}');
        expect(cart.total, 5);
      },
    );

    test(
      'a missing status/total/message leaves them null, not a default value',
      () {
        printTestDivider(
          'Cart.fromJson missing envelope fields stay null (no ?? fallback here)',
        );
        final cart = Cart.fromJson({});

        printTestLog('status → expected: null, actual: ${cart.status}');
        expect(cart.status, isNull);
        printTestLog('message → expected: null, actual: ${cart.message}');
        expect(cart.message, isNull);
        printTestLog('total → expected: null, actual: ${cart.total}');
        expect(cart.total, isNull);
      },
    );

    test(
      'data is null when the raw "data" value is missing, null, or not a Map',
      () {
        printTestDivider(
          'Cart.fromJson data null for missing/null/non-Map "data"',
        );
        printTestLog('missing data key → expected: null');
        expect(Cart.fromJson({'status': 1}).data, isNull);
        printTestLog('explicit null data → expected: null');
        expect(Cart.fromJson({'status': 1, 'data': null}).data, isNull);
        printTestLog('data as a String (wrong type) → expected: null');
        expect(
          Cart.fromJson({'status': 1, 'data': 'not a map'}).data,
          isNull,
        );
      },
    );

    test('toJson round trip includes data only when data != null', () {
      printTestDivider('Cart.toJson round trip');
      final cart = Cart.fromJson(fixture());
      final json = cart.toJson();

      printTestLog('status → expected: 1, actual: ${json['status']}');
      expect(json['status'], 1);
      printTestLog('data present → expected: true, actual: ${json.containsKey('data')}');
      expect(json.containsKey('data'), isTrue);

      final noData = Cart(status: 1, message: 'x', total: 0);
      printTestLog(
        'no data → key absent, expected: false, actual: ${noData.toJson().containsKey('data')}',
      );
      expect(noData.toJson().containsKey('data'), isFalse);
    });
  });

  group('CartData.fromJson', () {
    test('parses every scalar field off a full fixture', () {
      printTestDivider('CartData.fromJson parses every scalar field');
      final data = Cart.fromJson(fixture()).data!;

      printTestLog('codAllowed → expected: 1, actual: ${data.codAllowed}');
      expect(data.codAllowed, 1);
      printTestLog(
        'productVariantId → expected: "12", actual: "${data.productVariantId}"',
      );
      expect(data.productVariantId, '12');
      printTestLog('quantity → expected: "3", actual: "${data.quantity}"');
      expect(data.quantity, '3');
      printTestLog('distance → expected: "4.2", actual: "${data.distance}"');
      expect(data.distance, '4.2');
      printTestLog(
        'timeToDeliver → expected: "30 mins", actual: "${data.timeToDeliver}"',
      );
      expect(data.timeToDeliver, '30 mins');
      printTestLog(
        'unlockPromoCodeId → expected: 7, actual: ${data.unlockPromoCodeId}',
      );
      expect(data.unlockPromoCodeId, 7);
      printTestLog(
        'isDeliverableAddress → expected: 1, actual: ${data.isDeliverableAddress}',
      );
      expect(data.isDeliverableAddress, 1);
      printTestLog(
        'totalAmount → expected: 250.5, actual: ${data.totalAmount}',
      );
      expect(data.totalAmount, 250.5);
      printTestLog('userBalance → expected: 100.0, actual: ${data.userBalance}');
      expect(data.userBalance, 100.0);
      printTestLog('subTotal → expected: 200.0, actual: ${data.subTotal}');
      expect(data.subTotal, 200.0);
      printTestLog('savedAmount → expected: 15.0, actual: ${data.savedAmount}');
      expect(data.savedAmount, 15.0);
      printTestLog(
        'minimumOrderAmount → expected: 50.0, actual: ${data.minimumOrderAmount}',
      );
      expect(data.minimumOrderAmount, 50.0);
      printTestLog('currency → expected: "\$", actual: "${data.currency}"');
      expect(data.currency, '\$');
      printTestLog('decimalPoint → expected: 2, actual: ${data.decimalPoint}');
      expect(data.decimalPoint, 2);
    });

    test('deliveryCharge parses via DeliveryCharges.fromJson when a Map', () {
      printTestDivider('CartData.fromJson deliveryCharge nested parse');
      final data = Cart.fromJson(fixture()).data!;

      printTestLog(
        'deliveryCharge.amount → expected: 20.0, actual: ${data.deliveryCharges?.amount}',
      );
      expect(data.deliveryCharges?.amount, 20.0);
      printTestLog(
        'deliveryCharge.taxName → expected: "GST", actual: "${data.deliveryCharges?.taxName}"',
      );
      expect(data.deliveryCharges?.taxName, 'GST');
    });

    test('deliveryCharge is null when "delivery_charges" is missing/not a Map', () {
      printTestDivider('CartData.fromJson deliveryCharge null on missing/wrong type');
      final data = CartData.fromJson({});
      expect(data.deliveryCharges, isNull);
      final wrongType = CartData.fromJson({'delivery_charges': 'nope'});
      expect(wrongType.deliveryCharges, isNull);
    });

    test(
      'surgeCharges/zoneAdditionalCharges parse each entry when a List, '
      'and default to an EMPTY LIST (not null) when missing',
      () {
        printTestDivider(
          'CartData.fromJson surgeCharges/zoneAdditionalCharges default to []',
        );
        final data = Cart.fromJson(fixture()).data!;
        printTestLog(
          'surgeCharges length → expected: 1, actual: ${data.surgeCharges?.length}',
        );
        expect(data.surgeCharges, hasLength(1));
        printTestLog(
          'surgeCharges[0].label → expected: "Peak hour surge", actual: "${data.surgeCharges?[0].label}"',
        );
        expect(data.surgeCharges?[0].label, 'Peak hour surge');
        printTestLog(
          'zoneAdditionalCharges[0].name → expected: "Handling charge", actual: "${data.zoneAdditionalCharges?[0].name}"',
        );
        expect(data.zoneAdditionalCharges?[0].name, 'Handling charge');

        final empty = CartData.fromJson({});
        printTestLog(
          'missing surge_charges → expected: [] (not null), actual: ${empty.surgeCharges}',
        );
        expect(empty.surgeCharges, isNotNull);
        expect(empty.surgeCharges, isEmpty);
        printTestLog(
          'missing zone_additional_charges → expected: [] (not null), actual: ${empty.zoneAdditionalCharges}',
        );
        expect(empty.zoneAdditionalCharges, isNotNull);
        expect(empty.zoneAdditionalCharges, isEmpty);
      },
    );

    test(
      'cart/additionalCharges/taxBreakdown stay NULL (not []) when missing — '
      'the opposite default from surgeCharges/zoneAdditionalCharges above, '
      'since these three have no "else" branch in fromJson',
      () {
        printTestDivider(
          'CartData.fromJson cart/additionalCharges/taxBreakdown default to null',
        );
        final empty = CartData.fromJson({});
        printTestLog('cart → expected: null, actual: ${empty.cart}');
        expect(empty.cart, isNull);
        printTestLog(
          'additionalCharges → expected: null, actual: ${empty.additionalCharges}',
        );
        expect(empty.additionalCharges, isNull);
        printTestLog(
          'taxBreakdown → expected: null, actual: ${empty.taxBreakdown}',
        );
        expect(empty.taxBreakdown, isNull);

        // Also null (not []) when explicitly present but the wrong type.
        final wrongType = CartData.fromJson({
          'cart': 'not a list',
          'additional_charges': 42,
          'tax_breakdown': {'a': 1},
        });
        expect(wrongType.cart, isNull);
        expect(wrongType.additionalCharges, isNull);
        expect(wrongType.taxBreakdown, isNull);
      },
    );

    test('cart items parse via ProductDataModel.fromJson', () {
      printTestDivider('CartData.fromJson cart items parse via ProductDataModel');
      final data = Cart.fromJson(fixture()).data!;

      printTestLog('cart length → expected: 2, actual: ${data.cart?.length}');
      expect(data.cart, hasLength(2));
      final first = data.cart!.first;
      printTestLog(
        'first.productName → expected: "Organic Apples 1kg", actual: "${first.productName}"',
      );
      expect(first.productName, 'Organic Apples 1kg');
      printTestLog(
        'first.variants[0].quantity → expected: 2, actual: ${first.variants?.first.quantity}',
      );
      expect(first.variants?.first.quantity, 2);
    });

    test('additionalCharges and taxBreakdown parse every entry', () {
      printTestDivider('CartData.fromJson additionalCharges/taxBreakdown parse');
      final data = Cart.fromJson(fixture()).data!;

      printTestLog(
        'additionalCharges[0].name → expected: "Packaging charge", actual: "${data.additionalCharges?[0].name}"',
      );
      expect(data.additionalCharges?[0].name, 'Packaging charge');
      printTestLog(
        'taxBreakdown[0].rate → expected: 5, actual: ${data.taxBreakdown?[0].rate}',
      );
      expect(data.taxBreakdown?[0].rate, 5);
      printTestLog(
        'taxBreakdown[0].amount → expected: 4.3, actual: ${data.taxBreakdown?[0].amount}',
      );
      expect(data.taxBreakdown?[0].amount, 4.3);
    });

    test(
      'totalAmount/subTotal/savedAmount/minimumOrderAmount default to 0.0 '
      '(parseDouble), but userBalance stays null (parseDoubleOrNull)',
      () {
        printTestDivider(
          'CartData.fromJson numeric defaults differ per field (0.0 vs null)',
        );
        final data = CartData.fromJson({});

        printTestLog('totalAmount → expected: 0.0, actual: ${data.totalAmount}');
        expect(data.totalAmount, 0.0);
        printTestLog('subTotal → expected: 0.0, actual: ${data.subTotal}');
        expect(data.subTotal, 0.0);
        printTestLog('savedAmount → expected: 0.0, actual: ${data.savedAmount}');
        expect(data.savedAmount, 0.0);
        printTestLog(
          'minimumOrderAmount → expected: 0.0, actual: ${data.minimumOrderAmount}',
        );
        expect(data.minimumOrderAmount, 0.0);
        printTestLog('userBalance → expected: null, actual: ${data.userBalance}');
        expect(data.userBalance, isNull);
      },
    );

    test(
      'string fields (productVariantId, quantity, distance, etc.) and int '
      'fields (codAllowed, unlockPromoCodeId, decimalPoint, etc.) all stay '
      'null when missing — none of them carry a "?? default" in this model',
      () {
        printTestDivider(
          'CartData.fromJson string/int fields default to null, not "" or 0',
        );
        final data = CartData.fromJson({});

        expect(data.productVariantId, isNull);
        expect(data.quantity, isNull);
        expect(data.distance, isNull);
        expect(data.timeToDeliver, isNull);
        expect(data.unlockMessage, isNull);
        expect(data.unlockPromoCode, isNull);
        expect(data.currency, isNull);
        expect(data.codAllowed, isNull);
        expect(data.unlockPromoCodeId, isNull);
        expect(data.isDeliverableAddress, isNull);
        expect(data.decimalPoint, isNull);
      },
    );
  });

  group('CartData.toJson', () {
    test('deliveryCharge/cart/additionalCharges/taxBreakdown round-trip via their own toJson', () {
      printTestDivider(
        'CartData.toJson deliveryCharge/cart/additionalCharges/taxBreakdown serialize as Maps',
      );
      final data = Cart.fromJson(fixture()).data!;
      final json = data.toJson();

      printTestLog(
        'delivery_charges → expected: Map, actual: ${json['delivery_charges'].runtimeType}',
      );
      expect(json['delivery_charges'], isA<Map>());
      printTestLog(
        'cart[0] → expected: Map, actual: ${(json['cart'] as List).first.runtimeType}',
      );
      expect((json['cart'] as List).first, isA<Map>());
      printTestLog(
        'additional_charges[0] → expected: Map, actual: ${(json['additional_charges'] as List).first.runtimeType}',
      );
      expect((json['additional_charges'] as List).first, isA<Map>());
      printTestLog(
        'tax_breakdown[0] → expected: Map, actual: ${(json['tax_breakdown'] as List).first.runtimeType}',
      );
      expect((json['tax_breakdown'] as List).first, isA<Map>());
    });

    test(
      'GOTCHA: surge_charges/zone_additional_charges are assigned as raw '
      'model-object lists, NOT mapped through their own .toJson() like every '
      'other nested list on this model — jsonEncode(cart.toJson()) would '
      'throw on these two keys since SurgeCharges/AdditionalCharges are not '
      'natively JSON-encodable',
      () {
        printTestDivider(
          'CartData.toJson surge_charges/zone_additional_charges stay raw objects (bug)',
        );
        final data = Cart.fromJson(fixture()).data!;
        final json = data.toJson();

        printTestLog(
          'surge_charges[0] runtimeType → expected: SurgeCharges (NOT Map), actual: ${(json['surge_charges'] as List).first.runtimeType}',
        );
        expect((json['surge_charges'] as List).first, isNot(isA<Map>()));
        printTestLog(
          'zone_additional_charges[0] runtimeType → expected: AdditionalCharges (NOT Map), actual: ${(json['zone_additional_charges'] as List).first.runtimeType}',
        );
        expect((json['zone_additional_charges'] as List).first, isNot(isA<Map>()));
      },
    );
  });
}
