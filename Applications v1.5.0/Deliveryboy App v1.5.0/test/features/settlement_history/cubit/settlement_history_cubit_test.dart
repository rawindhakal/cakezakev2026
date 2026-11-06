import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/settlement_history/cubit/settlement_history_cubit.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';

import '../../../helpers/mock_settlement_history_repository.dart';
import '../../../helpers/test_logging.dart';

/// SettlementHistoryCubit is a thin filter wrapper over the shared pagination
/// base (covered on its own in test/commons/cubit), so these tests focus on
/// what it adds: the repository call its fetcher makes, how the four filters
/// merge, and the hasActiveFilters getter the screen's badge reads.
void main() {
  late MockSettlementHistoryRepository repository;

  setUp(() => repository = MockSettlementHistoryRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  SettlementHistoryData entry(String id) =>
      SettlementHistoryData.fromJson({'id': id});

  SettlementHistoryResponse response(
    List<SettlementHistoryData> data,
    int total,
  ) => SettlementHistoryResponse(data: data, total: total);

  void stubTransfers({SettlementHistoryResponse? result}) {
    when(
      () => repository.getSettlementHistorys(
        search: any(named: 'search'),
        entryType: any(named: 'entryType'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => result ?? response([entry('901')], 1));
  }

  test('loadTransfers loads the first page with empty filters', () async {
    printTestDivider(
      'SettlementHistoryCubit loadTransfers loads the first page with empty filters',
    );
    stubTransfers();
    final cubit = SettlementHistoryCubit(repository: repository);

    await cubit.loadTransfers();

    verify(
      () => repository.getSettlementHistorys(
        search: '',
        entryType: '',
        startDate: null,
        endDate: null,
        offset: 0,
      ),
    ).called(1);
    printTestLog(
      'state → expected: PaginationLoaded, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<PaginationLoaded<SettlementHistoryData>>());
    await cubit.close();
  });

  test('a null data block loads as an empty list rather than failing', () async {
    printTestDivider(
      'SettlementHistoryCubit a null data block loads as an empty list rather than failing',
    );
    // The fetcher maps `result.data ?? []` — a null list from the api is a
    // valid empty page, not an error.
    stubTransfers(result: SettlementHistoryResponse(data: null, total: null));
    final cubit = SettlementHistoryCubit(repository: repository);

    await cubit.loadTransfers();

    final state = cubit.state as PaginationLoaded<SettlementHistoryData>;
    printTestLog('data → expected: [], actual: ${state.data}');
    expect(state.data, isEmpty);
    printTestLog('total → expected: 0, actual: ${state.total}');
    expect(state.total, 0);
    await cubit.close();
  });

  test('updateFilters applies every filter and reloads from the first page', () async {
    printTestDivider(
      'SettlementHistoryCubit updateFilters applies every filter and reloads from the first page',
    );
    stubTransfers();
    final cubit = SettlementHistoryCubit(repository: repository);

    await cubit.updateFilters(
      search: '901',
      entryType: 'withdrawal',
      startDate: '2026-08-01',
      endDate: '2026-08-17',
    );

    verify(
      () => repository.getSettlementHistorys(
        search: '901',
        entryType: 'withdrawal',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
        offset: 0,
      ),
    ).called(1);
    printTestLog('search → expected: "901", actual: "${cubit.search}"');
    expect(cubit.search, '901');
    printTestLog('entryType → expected: "withdrawal", actual: "${cubit.entryType}"');
    expect(cubit.entryType, 'withdrawal');
    await cubit.close();
  });

  test('an omitted search/entryType keeps its current value', () async {
    printTestDivider(
      'SettlementHistoryCubit an omitted search/entryType keeps its current value',
    );
    stubTransfers();
    final cubit = SettlementHistoryCubit(repository: repository);

    await cubit.updateFilters(search: '901', entryType: 'withdrawal');
    await cubit.updateFilters(startDate: '2026-08-01', endDate: '2026-08-17');

    printTestLog('search → expected: "901", actual: "${cubit.search}"');
    expect(cubit.search, '901');
    printTestLog('entryType → expected: "withdrawal", actual: "${cubit.entryType}"');
    expect(cubit.entryType, 'withdrawal');
    await cubit.close();
  });

  test('omitted dates are cleared, not kept — the asymmetry with search/entryType', () async {
    printTestDivider(
      'SettlementHistoryCubit omitted dates are cleared, not kept — the asymmetry with search/entryType',
    );
    // Documented behaviour: startDate/endDate pass through as-is (including
    // null) so callers can clear the range, while search/entryType merge.
    // Callers that want to keep the dates must re-pass them explicitly —
    // which is exactly what the screen's `_onSearchChanged` does.
    stubTransfers();
    final cubit = SettlementHistoryCubit(repository: repository);

    await cubit.updateFilters(startDate: '2026-08-01', endDate: '2026-08-17');
    await cubit.updateFilters(search: '901');

    printTestLog('startDate → expected: null, actual: ${cubit.startDate}');
    expect(cubit.startDate, isNull);
    printTestLog('endDate → expected: null, actual: ${cubit.endDate}');
    expect(cubit.endDate, isNull);
    printTestLog('search → expected: "901", actual: "${cubit.search}"');
    expect(cubit.search, '901');
    await cubit.close();
  });

  test('loadMore pages from the current offset with the active filters still applied', () async {
    printTestDivider(
      'SettlementHistoryCubit loadMore pages from the current offset with the active filters still applied',
    );
    stubTransfers(result: response([entry('901'), entry('902')], 10));
    final cubit = SettlementHistoryCubit(repository: repository);

    await cubit.updateFilters(entryType: 'withdrawal');
    await cubit.loadMore();

    verify(
      () => repository.getSettlementHistorys(
        search: '',
        entryType: 'withdrawal',
        startDate: null,
        endDate: null,
        offset: 2,
      ),
    ).called(1);
    printTestLog('loadMore offset 2 with entryType "withdrawal" → verified');
    await cubit.close();
  });

  test('clearFilters resets every filter and reloads', () async {
    printTestDivider('SettlementHistoryCubit clearFilters resets every filter and reloads');
    stubTransfers();
    final cubit = SettlementHistoryCubit(repository: repository);

    await cubit.updateFilters(
      search: '901',
      entryType: 'withdrawal',
      startDate: '2026-08-01',
      endDate: '2026-08-17',
    );
    printTestLog('hasActiveFilters → expected: true, actual: ${cubit.hasActiveFilters}');
    expect(cubit.hasActiveFilters, isTrue);

    await cubit.clearFilters();

    printTestLog('hasActiveFilters → expected: false, actual: ${cubit.hasActiveFilters}');
    expect(cubit.hasActiveFilters, isFalse);
    printTestLog('search → expected: "", actual: "${cubit.search}"');
    expect(cubit.search, '');
    printTestLog('entryType → expected: "", actual: "${cubit.entryType}"');
    expect(cubit.entryType, '');
    printTestLog('startDate → expected: null, actual: ${cubit.startDate}');
    expect(cubit.startDate, isNull);
    printTestLog('endDate → expected: null, actual: ${cubit.endDate}');
    expect(cubit.endDate, isNull);
    await cubit.close();
  });

  group('hasActiveFilters', () {
    test('is false on a freshly built cubit', () async {
      printTestDivider('SettlementHistoryCubit hasActiveFilters is false on a freshly built cubit');
      final cubit = SettlementHistoryCubit(repository: repository);

      printTestLog('hasActiveFilters → expected: false, actual: ${cubit.hasActiveFilters}');
      expect(cubit.hasActiveFilters, isFalse);
      await cubit.close();
    });

    test('is true when any single filter is set on its own', () async {
      printTestDivider(
        'SettlementHistoryCubit hasActiveFilters is true when any single filter is set on its own',
      );
      stubTransfers();

      for (final apply in <Future<void> Function(SettlementHistoryCubit)>[
        (c) => c.updateFilters(search: '901'),
        (c) => c.updateFilters(entryType: 'withdrawal'),
        (c) => c.updateFilters(startDate: '2026-08-01'),
        (c) => c.updateFilters(endDate: '2026-08-17'),
      ]) {
        final cubit = SettlementHistoryCubit(repository: repository);
        await apply(cubit);
        printTestLog('hasActiveFilters → expected: true, actual: ${cubit.hasActiveFilters}');
        expect(cubit.hasActiveFilters, isTrue);
        await cubit.close();
      }
    });

    test('the "all" entry type does not count as an active filter', () async {
      printTestDivider(
        'SettlementHistoryCubit hasActiveFilters the "all" entry type does not count as an active filter',
      );
      stubTransfers();
      final cubit = SettlementHistoryCubit(repository: repository);

      // Applying "All" from the filter sheet sends the empty wire value, so
      // the screen's badge must go back to hidden rather than staying lit.
      await cubit.updateFilters(entryType: '');

      printTestLog('hasActiveFilters → expected: false, actual: ${cubit.hasActiveFilters}');
      expect(cubit.hasActiveFilters, isFalse);
      await cubit.close();
    });
  });

  test('surfaces the API message when the list fails', () async {
    printTestDivider('SettlementHistoryCubit surfaces the API message when the list fails');
    when(
      () => repository.getSettlementHistorys(
        search: any(named: 'search'),
        entryType: any(named: 'entryType'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(const ApiException(message: 'Settlement history unavailable'));
    final cubit = SettlementHistoryCubit(repository: repository);

    await cubit.loadTransfers();

    final state = cubit.state as PaginationError<SettlementHistoryData>;
    printTestLog(
      'message → expected: "Settlement history unavailable", actual: "${state.message}"',
    );
    expect(state.message, 'Settlement history unavailable');
    await cubit.close();
  });
}
