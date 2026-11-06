import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/guest_cart_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/auth/models/auth_model.dart';
import 'package:customer/features/cart/cubit/cart_cubit.dart';
import 'package:customer/features/products/models/product_model.dart';

import '../../../helpers/test_logging.dart';

/// `CartCubit` needs `settingsBox` (channel, max-cart-items setting),
/// `authBox` (isLoggedIn — gates guest-cart persistence/switching) and
/// `guestCartBox` (`GuestCartHiveBox`, guest cart persistence) open
/// simultaneously — `test/helpers/hive_test_helper.dart` only opens one box
/// per call, so this file manages its own multi-box temp-dir setup rather
/// than stacking three separate `HiveTestHelper.setUp` calls against three
/// different temp dirs (which would make `HiveTestHelper.tearDown`'s
/// single-`_tempDir` bookkeeping delete the wrong directory).
///
/// `loadFromApi()` itself is NOT covered here: unlike every other cart cubit
/// (`CartFetchCubit`, `CartActionCubit`, ...), `CartCubit` does not accept an
/// injected `CartRepository` — it always does `CartRepository().getCart()`
/// internally, hitting the real `ApiClient`/network. `seedFromApi`, the
/// method `loadFromApi` delegates to for turning a response into cart
/// entries, is fully covered below instead, since that's the actual mapping
/// logic worth testing.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cart_cubit_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(settingsBox);
    await Hive.openBox(authBox);
    await Hive.openBox(guestCartBox);
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.box(authBox).close();
    await Hive.box(guestCartBox).close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  ProductDataModel product({
    required int id,
    required int variantId,
    double price = 100.0,
    double discountedPrice = 0.0,
    int quantity = 1,
    String? salesChannel,
    String variantImage = '',
    String productImage = '',
  }) => ProductDataModel.fromJson({
    'id': id,
    'sales_channel': salesChannel,
    'price': price,
    'discounted_price': discountedPrice,
    'variant_id': variantId,
    'variants': [
      {
        'id': variantId,
        'quantity': quantity,
        if (variantImage.isNotEmpty) 'image': variantImage,
      },
    ],
    if (productImage.isNotEmpty) 'images': [{'image_url': productImage}],
  });

  group('CartState', () {
    test('totalItems/totalPrice/countFor/previewImages compute from entries', () {
      printTestDivider('CartState totalItems/totalPrice/countFor/previewImages');
      const state = CartState(
        entries: {
          'v1': CartEntry(
            variantId: 'v1',
            price: 10.0,
            quantity: 2,
            imageUrl: 'a.jpg',
          ),
          'v2': CartEntry(
            variantId: 'v2',
            price: 5.0,
            quantity: 3,
            imageUrl: 'b.jpg',
          ),
        },
      );

      printTestLog('totalItems → expected: 5, actual: ${state.totalItems}');
      expect(state.totalItems, 5);
      printTestLog('totalPrice → expected: 35.0, actual: ${state.totalPrice}');
      expect(state.totalPrice, 35.0);
      printTestLog('countFor(v1) → expected: 2, actual: ${state.countFor('v1')}');
      expect(state.countFor('v1'), 2);
      printTestLog('countFor(missing) → expected: 0, actual: ${state.countFor('vX')}');
      expect(state.countFor('vX'), 0);
      printTestLog(
        'previewImages → expected: [a.jpg, b.jpg], actual: ${state.previewImages}',
      );
      expect(state.previewImages, ['a.jpg', 'b.jpg']);
    });

    test('previewImages drops empty urls, dedupes, and caps at 3', () {
      printTestDivider('CartState previewImages drops empty/dedupes/caps at 3');
      const state = CartState(
        entries: {
          'v1': CartEntry(variantId: 'v1', price: 1, quantity: 1, imageUrl: ''),
          'v2': CartEntry(variantId: 'v2', price: 1, quantity: 1, imageUrl: 'a.jpg'),
          'v3': CartEntry(variantId: 'v3', price: 1, quantity: 1, imageUrl: 'a.jpg'),
          'v4': CartEntry(variantId: 'v4', price: 1, quantity: 1, imageUrl: 'b.jpg'),
          'v5': CartEntry(variantId: 'v5', price: 1, quantity: 1, imageUrl: 'c.jpg'),
          'v6': CartEntry(variantId: 'v6', price: 1, quantity: 1, imageUrl: 'd.jpg'),
        },
      );

      printTestLog('previewImages length → expected: 3, actual: ${state.previewImages.length}');
      expect(state.previewImages, hasLength(3));
    });
  });

  group('canAddMore / add', () {
    test('canAddMore is true when no max-cart-items setting is saved (limit 0 = unlimited)', () {
      printTestDivider('canAddMore true when limit is 0/unset');
      final cubit = CartCubit();
      expect(cubit.canAddMore, isTrue);
      cubit.close();
    });

    test('add() creates a new entry with quantity 1 and the given image', () {
      printTestDivider('add() creates a new entry');
      final cubit = CartCubit();

      cubit.add('v1', 25.0, imageUrl: 'x.jpg');

      printTestLog('entries[v1] → expected: qty 1 price 25.0, actual: ${cubit.state.entries['v1']?.quantity}/${cubit.state.entries['v1']?.price}');
      expect(cubit.state.entries['v1']?.quantity, 1);
      expect(cubit.state.entries['v1']?.price, 25.0);
      expect(cubit.state.entries['v1']?.imageUrl, 'x.jpg');
      cubit.close();
    });

    test('add() increments an existing entry and keeps its original image', () {
      printTestDivider('add() increments existing entry, keeps original image');
      final cubit = CartCubit();

      cubit.add('v1', 25.0, imageUrl: 'first.jpg');
      cubit.add('v1', 25.0, imageUrl: 'second.jpg');

      printTestLog('quantity → expected: 2, actual: ${cubit.state.entries['v1']?.quantity}');
      expect(cubit.state.entries['v1']?.quantity, 2);
      printTestLog(
        'imageUrl → expected: "first.jpg" (kept), actual: "${cubit.state.entries['v1']?.imageUrl}"',
      );
      expect(cubit.state.entries['v1']?.imageUrl, 'first.jpg');
      cubit.close();
    });

    test('add() is a no-op once the saved max-cart-items limit is reached', () async {
      printTestDivider('add() no-op once max-cart-items limit reached');
      await SettingsHiveBox.instance.saveAppSettings(
        AppSettingsData(maxCartItemsCount: '2'),
      );
      final cubit = CartCubit();

      cubit.add('v1', 10.0);
      cubit.add('v2', 10.0);
      cubit.add('v3', 10.0); // limit reached at 2 total items already

      printTestLog('totalItems → expected: 2, actual: ${cubit.state.totalItems}');
      expect(cubit.state.totalItems, 2);
      printTestLog('canAddMore → expected: false, actual: ${cubit.canAddMore}');
      expect(cubit.canAddMore, isFalse);
      cubit.close();
    });

    test('add() persists to GuestCartHiveBox when not logged in', () {
      printTestDivider('add() persists to GuestCartHiveBox when logged out');
      final cubit = CartCubit();

      cubit.add('v1', 10.0, imageUrl: 'img.jpg');

      final saved = GuestCartHiveBox.instance.loadEntries(
        SettingsHiveBox.instance.channel,
      );
      printTestLog('saved[v1] → expected: present, actual: ${saved['v1']}');
      expect(saved['v1'], isNotNull);
      expect(saved['v1']?['quantity'], 1);
      cubit.close();
    });

    test('add() does NOT persist to GuestCartHiveBox when logged in', () async {
      printTestDivider('add() skips GuestCartHiveBox persistence when logged in');
      await AuthHiveBox.instance.saveLoginData(
        userLogin: _fakeLoggedInAuthModel(),
      );
      final cubit = CartCubit();

      cubit.add('v1', 10.0);

      final saved = GuestCartHiveBox.instance.loadEntries(
        SettingsHiveBox.instance.channel,
      );
      printTestLog('saved → expected: empty, actual: $saved');
      expect(saved, isEmpty);
      cubit.close();
    });
  });

  group('seedFromApi', () {
    test('maps items belonging to the current channel or "both"', () {
      printTestDivider('seedFromApi keeps current-channel and "both" items');
      final cubit = CartCubit(); // default channel = quick
      final items = [
        product(id: 1, variantId: 101, salesChannel: 'quick', quantity: 2),
        product(id: 2, variantId: 102, salesChannel: 'both', quantity: 1),
        product(id: 3, variantId: 103, salesChannel: 'ecommerce', quantity: 1),
      ];

      cubit.seedFromApi(items);

      printTestLog(
        'entries → expected: {101, 102} (103 filtered out), actual: ${cubit.state.entries.keys}',
      );
      expect(cubit.state.entries.keys, containsAll(['101', '102']));
      expect(cubit.state.entries.containsKey('103'), isFalse);
      cubit.close();
    });

    test('items with quantity <= 0 are dropped', () {
      printTestDivider('seedFromApi drops quantity <= 0 items');
      final cubit = CartCubit();
      final items = [product(id: 1, variantId: 101, quantity: 0)];

      cubit.seedFromApi(items);

      printTestLog('entries → expected: empty, actual: ${cubit.state.entries}');
      expect(cubit.state.entries, isEmpty);
      cubit.close();
    });

    test('price prefers a positive discountedPrice over price', () {
      printTestDivider('seedFromApi price prefers positive discountedPrice');
      final cubit = CartCubit();
      final discounted = product(
        id: 1,
        variantId: 101,
        price: 100.0,
        discountedPrice: 80.0,
      );
      final notDiscounted = product(
        id: 2,
        variantId: 102,
        price: 50.0,
        discountedPrice: 0.0,
      );

      cubit.seedFromApi([discounted, notDiscounted]);

      printTestLog(
        '101 price → expected: 80.0, actual: ${cubit.state.entries['101']?.price}',
      );
      expect(cubit.state.entries['101']?.price, 80.0);
      printTestLog(
        '102 price → expected: 50.0 (discountedPrice is 0), actual: ${cubit.state.entries['102']?.price}',
      );
      expect(cubit.state.entries['102']?.price, 50.0);
      cubit.close();
    });

    test('image prefers the variant image over the product images list', () {
      printTestDivider('seedFromApi image prefers variant image');
      final cubit = CartCubit();
      final withVariantImage = product(
        id: 1,
        variantId: 101,
        variantImage: 'variant.jpg',
        productImage: 'product.jpg',
      );

      cubit.seedFromApi([withVariantImage]);

      printTestLog(
        'imageUrl → expected: "variant.jpg", actual: "${cubit.state.entries['101']?.imageUrl}"',
      );
      expect(cubit.state.entries['101']?.imageUrl, 'variant.jpg');
      cubit.close();
    });

    test('id falls back to the first variant id when variantId itself is absent', () {
      printTestDivider('seedFromApi id falls back to variants.first.id');
      final cubit = CartCubit();
      final item = ProductDataModel.fromJson({
        'id': 5,
        // no top-level "variant_id"
        'price': 10.0,
        'variants': [
          {'id': 999, 'quantity': 1},
        ],
      });

      cubit.seedFromApi([item]);

      printTestLog('entries → expected: {999}, actual: ${cubit.state.entries.keys}');
      expect(cubit.state.entries.containsKey('999'), isTrue);
      cubit.close();
    });

    test('an item with no variantId and no variants at all is skipped', () {
      printTestDivider('seedFromApi skips an item with no id source at all');
      final cubit = CartCubit();
      final item = ProductDataModel.fromJson({'id': 6, 'price': 10.0});

      cubit.seedFromApi([item]);

      printTestLog('entries → expected: empty, actual: ${cubit.state.entries}');
      expect(cubit.state.entries, isEmpty);
      cubit.close();
    });
  });

  group('remove / removeAll / setQuantity / clear', () {
    test('remove() decrements quantity, dropping the entry once it hits 0', () {
      printTestDivider('remove() decrements, drops at 0');
      final cubit = CartCubit();
      cubit.add('v1', 10.0);
      cubit.add('v1', 10.0); // quantity 2

      cubit.remove('v1', 10.0);
      printTestLog('quantity after 1 remove → expected: 1, actual: ${cubit.state.entries['v1']?.quantity}');
      expect(cubit.state.entries['v1']?.quantity, 1);

      cubit.remove('v1', 10.0);
      printTestLog('entries after 2nd remove → expected: empty, actual: ${cubit.state.entries}');
      expect(cubit.state.entries, isEmpty);
      cubit.close();
    });

    test('remove() on a variant not in the cart is a no-op', () {
      printTestDivider('remove() no-op for an absent variant');
      final cubit = CartCubit();
      cubit.remove('missing', 10.0);
      expect(cubit.state.entries, isEmpty);
      cubit.close();
    });

    test('removeAll() drops the line item regardless of quantity', () {
      printTestDivider('removeAll() drops regardless of quantity');
      final cubit = CartCubit();
      cubit.add('v1', 10.0);
      cubit.add('v1', 10.0);
      cubit.add('v1', 10.0);

      cubit.removeAll('v1');

      printTestLog('entries → expected: empty, actual: ${cubit.state.entries}');
      expect(cubit.state.entries, isEmpty);
      cubit.close();
    });

    test('setQuantity() sets an exact value, removing the entry when <= 0', () {
      printTestDivider('setQuantity() exact value, removes at <= 0');
      final cubit = CartCubit();

      cubit.setQuantity('v1', 15.0, 4, imageUrl: 'img.jpg');
      printTestLog('quantity → expected: 4, actual: ${cubit.state.entries['v1']?.quantity}');
      expect(cubit.state.entries['v1']?.quantity, 4);

      cubit.setQuantity('v1', 15.0, 0);
      printTestLog('entries after qty 0 → expected: empty, actual: ${cubit.state.entries}');
      expect(cubit.state.entries, isEmpty);
      cubit.close();
    });

    test('clear() empties state and clears the current channel\'s guest cart only', () {
      printTestDivider("clear() empties state, clears only the current channel");
      final cubit = CartCubit();
      cubit.add('v1', 10.0);
      GuestCartHiveBox.instance.saveEntries(
        {'other': {'variantId': 'other', 'price': 5, 'quantity': 1}},
        'ecommerce',
      );

      cubit.clear();

      printTestLog('entries → expected: empty, actual: ${cubit.state.entries}');
      expect(cubit.state.entries, isEmpty);
      printTestLog(
        'quick channel cleared → expected: true, actual: ${GuestCartHiveBox.instance.isEmptyFor('quick')}',
      );
      expect(GuestCartHiveBox.instance.isEmptyFor('quick'), isTrue);
      printTestLog(
        'ecommerce channel untouched → expected: false, actual: ${GuestCartHiveBox.instance.isEmptyFor('ecommerce')}',
      );
      expect(GuestCartHiveBox.instance.isEmptyFor('ecommerce'), isFalse);
      cubit.close();
    });

    test('clearAllGuestData() empties state and wipes every channel', () {
      printTestDivider('clearAllGuestData() wipes every channel');
      final cubit = CartCubit();
      GuestCartHiveBox.instance.saveEntries(
        {'a': {'variantId': 'a', 'price': 5, 'quantity': 1}},
        'quick',
      );
      GuestCartHiveBox.instance.saveEntries(
        {'b': {'variantId': 'b', 'price': 5, 'quantity': 1}},
        'ecommerce',
      );

      cubit.clearAllGuestData();

      expect(cubit.state.entries, isEmpty);
      expect(GuestCartHiveBox.instance.isEmptyFor('quick'), isTrue);
      expect(GuestCartHiveBox.instance.isEmptyFor('ecommerce'), isTrue);
      cubit.close();
    });
  });

  group('switchChannel / resetForChannelSwitch / loadGuestCartFromHive', () {
    test('switchChannel() loads the target channel\'s persisted entries when logged out', () async {
      printTestDivider("switchChannel() loads target channel's entries when logged out");
      await GuestCartHiveBox.instance.saveEntries(
        {
          'e1': {'variantId': 'e1', 'price': 20.0, 'quantity': 3, 'imageUrl': ''},
        },
        'ecommerce',
      );
      final cubit = CartCubit();

      cubit.switchChannel('ecommerce');

      printTestLog('entries → expected: {e1}, actual: ${cubit.state.entries.keys}');
      expect(cubit.state.entries.containsKey('e1'), isTrue);
      expect(cubit.state.entries['e1']?.quantity, 3);
      cubit.close();
    });

    test('switchChannel() is a no-op when the user is logged in', () async {
      printTestDivider('switchChannel() no-op when logged in');
      await AuthHiveBox.instance.saveLoginData(
        userLogin: _fakeLoggedInAuthModel(),
      );
      await GuestCartHiveBox.instance.saveEntries(
        {
          'e1': {'variantId': 'e1', 'price': 20.0, 'quantity': 3},
        },
        'ecommerce',
      );
      final cubit = CartCubit();
      cubit.add('v1', 10.0); // won't persist since logged in, just seeds state

      cubit.switchChannel('ecommerce');

      printTestLog(
        'entries unchanged → expected: still v1 only, actual: ${cubit.state.entries.keys}',
      );
      expect(cubit.state.entries.keys, ['v1']);
      cubit.close();
    });

    test('resetForChannelSwitch() drops the displayed cart without touching storage', () {
      printTestDivider('resetForChannelSwitch() drops state, keeps storage');
      final cubit = CartCubit();
      cubit.add('v1', 10.0);

      cubit.resetForChannelSwitch();

      printTestLog('entries → expected: empty, actual: ${cubit.state.entries}');
      expect(cubit.state.entries, isEmpty);
      final saved = GuestCartHiveBox.instance.loadEntries('quick');
      printTestLog('storage untouched → expected: still has v1, actual: $saved');
      expect(saved.containsKey('v1'), isTrue);
      cubit.close();
    });

    test('loadGuestCartFromHive() seeds state from the current channel\'s storage', () async {
      printTestDivider("loadGuestCartFromHive() seeds from current channel's storage");
      await GuestCartHiveBox.instance.saveEntries(
        {
          'q1': {'variantId': 'q1', 'price': 12.0, 'quantity': 2, 'imageUrl': 'q1.jpg'},
        },
        'quick',
      );
      final cubit = CartCubit();

      cubit.loadGuestCartFromHive();

      printTestLog('entries → expected: {q1}, actual: ${cubit.state.entries.keys}');
      expect(cubit.state.entries.containsKey('q1'), isTrue);
      expect(cubit.state.entries['q1']?.price, 12.0);
      cubit.close();
    });

    test('loadGuestCartFromHive() leaves state untouched when storage is empty', () {
      printTestDivider('loadGuestCartFromHive() no-op on empty storage');
      final cubit = CartCubit();
      cubit.add('existing', 1.0); // pre-existing in-memory state

      cubit.loadGuestCartFromHive();

      printTestLog(
        'entries → expected: still just "existing", actual: ${cubit.state.entries.keys}',
      );
      expect(cubit.state.entries.keys, ['existing']);
      cubit.close();
    });
  });
}

// Minimal AuthModel with a non-empty access token — enough for
// `AuthHiveBox.saveLoginData` to persist a "logged in" session, without
// pulling in the full auth fixtures.
AuthModel _fakeLoggedInAuthModel() => AuthModel.fromJson({
  'status': 1,
  'data': {'id': 1, 'access_token': 'test-token'},
});
