import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/features/home/models/enums/redirect_type.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/features/products/models/product_sort_type.dart';
import 'package:customer/features/products/repositories/product_repository.dart';

import '../../helpers/hive_test_helper.dart';
import '../../helpers/mock_api_client.dart';
import '../../helpers/test_logging.dart';

/// Home-builder banner with redirect_type "products" (API 1.5.0): parses
/// redirect_title/redirect_params, opens the list with the map as its
/// initial filter state, and sends it back unchanged to customer/products
/// and customer/products/filters.
void main() {
  const bannerParams = {
    'category_id': '2923',
    'max_price': '2974.6',
    'max_discount_percent': '50',
    'sort': 'discount',
  };

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('RedirectType', () {
    test('parses "products"', () {
      expect(RedirectType.fromRaw('products'), RedirectType.products);
      expect(RedirectType.fromRaw('product'), RedirectType.product);
    });
  });

  group('banner model', () {
    test('Items parses redirect_title and redirect_params as strings', () {
      final item = Items.fromJson({
        'redirect_type': 'products',
        'redirect_id': '',
        'redirect_title': 'Up to 50% Off',
        'redirect_params': {...bannerParams, 'brand_ids': '4,11'},
      });
      expect(RedirectType.fromRaw(item.redirectType), RedirectType.products);
      expect(item.redirectTitle, 'Up to 50% Off');
      expect(item.redirectParams, {...bannerParams, 'brand_ids': '4,11'});
    });

    test('empty title is null so the screen falls back to "Products"', () {
      final block = Blocks.fromJson({
        'type': 'title_image',
        'redirect_type': 'products',
        'redirect_title': '',
        'redirect_params': <String, dynamic>{},
      });
      expect(block.redirectTitle, isNull);
      expect(block.redirectParams, isEmpty);
    });

    test('all-blank params arriving as [] or missing mean no filters', () {
      expect(Items.fromJson({'redirect_params': []}).redirectParams, isEmpty);
      expect(Items.fromJson({}).redirectParams, isEmpty);
    });
  });

  group('ProductFilter.fromRedirectParams', () {
    test('maps every key; category_id is the scope', () {
      final f = ProductFilter.fromRedirectParams({
        'category_id': '2923',
        'brand_ids': '4,11',
        'attribute_value_ids': '7,9',
        'min_price': '100',
        'max_price': '2974.6',
        'min_discount_percent': '40',
        'max_discount_percent': '50',
        'sort': 'price_low',
      });
      expect(f.categoryId, '2923');
      expect(f.brandIds, {'4', '11'});
      expect(f.attributeValueIds, {'7', '9'});
      expect(f.minPrice, 100);
      expect(f.maxPrice, 2974.6);
      expect(f.minDiscountPercent, '40');
      expect(f.maxDiscountPercent, '50');
      expect(f.sort, ProductSortType.priceLowToHigh);
      expect(f.hasActiveFilters, isTrue);
    });

    test('empty map opens an unfiltered listing', () {
      final f = ProductFilter.fromRedirectParams(const {});
      expect(f.categoryId, '');
      expect(f.minPrice, isNull);
      expect(f.maxDiscountPercent, isNull);
      expect(f.sort, ProductSortType.defaultSort);
      expect(f.hasActiveFilters, isFalse);
    });

    test('every sort value maps; absent/unknown sort uses default', () {
      for (final (raw, type) in [
        ('new', ProductSortType.newestFirst),
        ('popular', ProductSortType.popularity),
        ('price_low', ProductSortType.priceLowToHigh),
        ('price_high', ProductSortType.priceHighToLow),
        ('discount', ProductSortType.discountHighToLow),
        ('bogus', ProductSortType.defaultSort),
      ]) {
        expect(ProductFilter.fromRedirectParams({'sort': raw}).sort, type);
      }
    });
  });

  group('requests', () {
    late MockApiClient api;
    late ProductCubit cubit;
    final sent = <Map<String, dynamic>>[];

    setUp(() async {
      await HiveTestHelper.setUp(settingsBox);
      api = MockApiClient();
      sent.clear();
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((inv) async {
        sent.add(
          Map<String, dynamic>.from(
            inv.namedArguments[#queryParameters] as Map,
          ),
        );
        return {'status': 1, 'message': '', 'data': [], 'total': 0};
      });
      cubit = ProductCubit(repository: ProductRepository(apiClient: api));
    });

    tearDown(() async {
      await cubit.close();
      await HiveTestHelper.tearDown(settingsBox);
    });

    test('listing spreads redirect_params on top of location/paging', () async {
      await cubit.loadProducts(redirectParams: bannerParams);
      final q = sent.single;
      expect(q['category_id'], '2923');
      expect(q['max_price'], 2974.6);
      expect(q['max_discount_percent'], '50');
      expect(q['sort'], 'discount');
      expect(q['offset'], 0);
      expect(q.containsKey('min_price'), isFalse);
      expect(q.containsKey('min_discount_percent'), isFalse);
      expect(q.containsKey('brand_ids'), isFalse);
    });

    test('empty result is a normal loaded state', () async {
      await cubit.loadProducts(redirectParams: bannerParams);
      expect(cubit.state, isA<PaginationLoaded<ProductDataModel>>());
      expect((cubit.state as PaginationLoaded<ProductDataModel>).data, isEmpty);
    });

    test('changing a filter keeps the banner map merged in', () async {
      await cubit.loadProducts(redirectParams: bannerParams);
      await cubit.applyProductFilters(
        minPrice: 10,
        maxPrice: 2974.6,
        brandIds: {'4'},
        attributeValueIds: {},
      );
      final q = sent.last;
      expect(q['category_id'], '2923');
      expect(q['max_discount_percent'], '50');
      expect(q['sort'], 'discount');
      expect(q['brand_ids'], '4');
      expect(q['min_price'], 10.0);
    });

    test('changing sort keeps the banner filters', () async {
      await cubit.loadProducts(redirectParams: bannerParams);
      await cubit.applySort(ProductSortType.newestFirst);
      final q = sent.last;
      expect(q['sort'], 'new');
      expect(q['max_discount_percent'], '50');
      expect(q['max_price'], 2974.6);
    });

    test('clear keeps category_id as scope and drops the rest', () async {
      await cubit.loadProducts(
        redirectParams: {...bannerParams, 'brand_ids': '4,11'},
      );
      await cubit.clearFilters();
      final q = sent.last;
      expect(q['category_id'], '2923');
      for (final k in [
        'max_price',
        'min_price',
        'max_discount_percent',
        'brand_ids',
        'sort',
      ]) {
        expect(q.containsKey(k), isFalse, reason: k);
      }
    });

    test('filters call gets the same map minus paging/sort', () async {
      when(
        () => api.get(
          ApiEndpoints.filters,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((inv) async {
        sent.add(
          Map<String, dynamic>.from(
            inv.namedArguments[#queryParameters] as Map,
          ),
        );
        return {'status': 1, 'message': '', 'data': {}};
      });
      await ProductRepository(apiClient: api).getFilters(
        categoryId: '2923',
        maxPrice: 2974.6,
        maxDiscountPercent: '50',
        attributeValueIds: '7,9',
      );
      final q = sent.last;
      expect(q['category_id'], '2923');
      expect(q['max_price'], 2974.6);
      expect(q['max_discount_percent'], '50');
      expect(q['attribute_value_ids'], '7,9');
      expect(q.containsKey('offset'), isFalse);
      expect(q.containsKey('sort'), isFalse);
    });
  });
}
