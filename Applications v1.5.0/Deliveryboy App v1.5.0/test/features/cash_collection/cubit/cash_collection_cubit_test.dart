import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/cash_collection/cubit/cash_collection_cubit.dart';
import 'package:deliveryboy/features/cash_collection/models/cash_collection_model.dart';

import '../../../helpers/mock_cash_collection_repository.dart';
import '../../../helpers/test_logging.dart';

/// CashCollectionCubit is a thin filter wrapper over the shared pagination
/// base (covered on its own in test/commons/cubit), so these tests focus on
/// what it adds: which repository call it makes, what it passes, and the
/// cashInHand/cashCollected getters read off the loaded meta.
void main() {
  late MockCashCollectionRepository repository;

  setUp(() => repository = MockCashCollectionRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  PaginatedResponse<CashCollectionModel> page(
    List<CashCollectionModel> data,
    int total, {
    CashCollectionMeta? meta,
  }) => PaginatedResponse(data: data, total: total, meta: meta);

  CashCollectionModel entry(String id) => CashCollectionModel.fromJson({
    'id': id,
  });

  void stubCollections({PaginatedResponse<CashCollectionModel>? response}) {
    when(
      () => repository.getCashCollections(
        search: any(named: 'search'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => response ?? page([entry('1')], 1));
  }

  test('loadCollections loads the first page with empty filters', () async {
    printTestDivider(
      'CashCollectionCubit loadCollections loads the first page with empty filters',
    );
    stubCollections();
    final cubit = CashCollectionCubit(repository: repository);

    await cubit.loadCollections();

    verify(
      () => repository.getCashCollections(
        search: '',
        startDate: null,
        endDate: null,
        offset: 0,
      ),
    ).called(1);
    printTestLog(
      'state → expected: PaginationLoaded, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<PaginationLoaded<CashCollectionModel>>());
    await cubit.close();
  });

  test('updateFilters applies filters and reloads from the first page', () async {
    printTestDivider(
      'CashCollectionCubit updateFilters applies filters and reloads from the first page',
    );
    stubCollections();
    final cubit = CashCollectionCubit(repository: repository);

    await cubit.updateFilters(
      search: 'TXN-000301',
      startDate: '2026-08-01',
      endDate: '2026-08-17',
    );

    verify(
      () => repository.getCashCollections(
        search: 'TXN-000301',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
        offset: 0,
      ),
    ).called(1);
    printTestLog('search → expected: "TXN-000301", actual: "${cubit.search}"');
    expect(cubit.search, 'TXN-000301');
    await cubit.close();
  });

  test('treats omitted filter values as cleared, not unchanged', () async {
    printTestDivider(
      'CashCollectionCubit treats omitted filter values as cleared, not unchanged',
    );
    stubCollections();
    final cubit = CashCollectionCubit(repository: repository);

    await cubit.updateFilters(search: 'TXN', startDate: '2026-08-01');
    await cubit.updateFilters(search: 'OTHER');

    printTestLog('startDate → expected: null, actual: ${cubit.startDate}');
    expect(cubit.startDate, isNull);
    printTestLog('search → expected: "OTHER", actual: "${cubit.search}"');
    expect(cubit.search, 'OTHER');
    await cubit.close();
  });

  test('clearFilters resets every filter', () async {
    printTestDivider('CashCollectionCubit clearFilters resets every filter');
    stubCollections();
    final cubit = CashCollectionCubit(repository: repository);

    await cubit.updateFilters(
      search: 'TXN',
      startDate: '2026-08-01',
      endDate: '2026-08-17',
    );
    printTestLog(
      'hasActiveFilters → expected: true, actual: ${cubit.hasActiveFilters}',
    );
    expect(cubit.hasActiveFilters, isTrue);

    await cubit.clearFilters();

    printTestLog(
      'hasActiveFilters → expected: false, actual: ${cubit.hasActiveFilters}',
    );
    expect(cubit.hasActiveFilters, isFalse);
    printTestLog('search → expected: "", actual: "${cubit.search}"');
    expect(cubit.search, '');
    await cubit.close();
  });

  test('hasActiveFilters is true when only a date is set', () async {
    printTestDivider(
      'CashCollectionCubit hasActiveFilters is true when only a date is set',
    );
    stubCollections();
    final cubit = CashCollectionCubit(repository: repository);

    await cubit.updateFilters(startDate: '2026-08-01');

    printTestLog(
      'hasActiveFilters → expected: true, actual: ${cubit.hasActiveFilters}',
    );
    expect(cubit.hasActiveFilters, isTrue);
    await cubit.close();
  });

  test('loadMore pages with the active filters still applied', () async {
    printTestDivider(
      'CashCollectionCubit loadMore pages with the active filters still applied',
    );
    stubCollections(response: page([entry('1'), entry('2')], 10));
    final cubit = CashCollectionCubit(repository: repository);

    await cubit.updateFilters(search: 'TXN');
    await cubit.loadMore();

    verify(
      () => repository.getCashCollections(
        search: 'TXN',
        startDate: null,
        endDate: null,
        offset: 2,
      ),
    ).called(1);
    await cubit.close();
  });

  test('surfaces the API message when the list fails', () async {
    printTestDivider(
      'CashCollectionCubit surfaces the API message when the list fails',
    );
    when(
      () => repository.getCashCollections(
        search: any(named: 'search'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(const ApiException(message: 'Cash collections unavailable'));
    final cubit = CashCollectionCubit(repository: repository);

    await cubit.loadCollections();

    final state = cubit.state as PaginationError<CashCollectionModel>;
    printTestLog(
      'message → expected: "Cash collections unavailable", actual: "${state.message}"',
    );
    expect(state.message, 'Cash collections unavailable');
    await cubit.close();
  });

  group('cashInHand / cashCollected getters', () {
    test('read off the loaded meta', () async {
      printTestDivider(
        'CashCollectionCubit cashInHand / cashCollected getters read off the loaded meta',
      );
      stubCollections(
        response: page(
          [entry('1')],
          1,
          meta: const CashCollectionMeta(
            cashInHand: '1245.50',
            cashCollected: '8420.75',
          ),
        ),
      );
      final cubit = CashCollectionCubit(repository: repository);

      await cubit.loadCollections();

      printTestLog(
        'cashInHand → expected: "1245.50", actual: ${cubit.cashInHand}',
      );
      expect(cubit.cashInHand, '1245.50');
      printTestLog(
        'cashCollected → expected: "8420.75", actual: ${cubit.cashCollected}',
      );
      expect(cubit.cashCollected, '8420.75');
      await cubit.close();
    });

    test('are null outside the loaded state', () async {
      printTestDivider(
        'CashCollectionCubit cashInHand / cashCollected getters are null outside the loaded state',
      );
      final cubit = CashCollectionCubit(repository: repository);

      printTestLog('cashInHand → expected: null, actual: ${cubit.cashInHand}');
      expect(cubit.cashInHand, isNull);
      printTestLog(
        'cashCollected → expected: null, actual: ${cubit.cashCollected}',
      );
      expect(cubit.cashCollected, isNull);
      await cubit.close();
    });
  });
}
