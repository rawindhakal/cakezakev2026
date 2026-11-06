import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_exception.dart';

import '../../helpers/test_logging.dart';

/// Minimal concrete cubit over the shared pagination base, so the base's own
/// behaviour (offsets, appending, hasMore, the stale-response guard) is tested
/// once here instead of being re-proved through every feature that extends it.
class _TestPaginationCubit extends BasePaginationCubit<String> {
  _TestPaginationCubit(this._fetcher);

  final PaginationFetcher<String> _fetcher;

  /// Offsets the cubit asked for, in order.
  final List<int> requestedOffsets = [];

  @override
  PaginationFetcher<String> get fetcher => (offset) {
    requestedOffsets.add(offset);
    return _fetcher(offset);
  };
}

typedef _Filters = ({String query});

class _TestFilteredCubit extends FilteredPaginationCubit<String, _Filters> {
  _TestFilteredCubit(this._fetcher) : super((query: ''));

  final Future<PaginatedResponse<String>> Function(String query, int offset)
  _fetcher;

  /// Every (query, offset) pair the cubit fetched with.
  final List<({String query, int offset})> requests = [];

  @override
  PaginationFetcher<String> buildFetcher(_Filters filters) => (offset) {
    requests.add((query: filters.query, offset: offset));
    return _fetcher(filters.query, offset);
  };
}

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  PaginatedResponse<String> page(
    List<String> data, {
    required int total,
    Object? meta,
  }) => PaginatedResponse(data: data, total: total, meta: meta);

  group('fetchInitial', () {
    blocTest<_TestPaginationCubit, PaginationState<String>>(
      'emits [Loading, Loaded] with the first page',
      setUp: () => printTestDivider('fetchInitial emits [Loading, Loaded] with the first page'),
      build: () => _TestPaginationCubit(
        (_) async => page(['a', 'b'], total: 5, meta: 'summary'),
      ),
      act: (cubit) => cubit.fetchInitial(),
      expect: () => [
        isA<PaginationLoading<String>>(),
        isA<PaginationLoaded<String>>()
            .having((s) => s.data, 'data', ['a', 'b'])
            .having((s) => s.total, 'total', 5)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.meta, 'meta', 'summary'),
      ],
      verify: (cubit) {
        printTestLog('offsets → expected: [0], actual: ${cubit.requestedOffsets}');
        expect(cubit.requestedOffsets, [0]);
      },
    );

    blocTest<_TestPaginationCubit, PaginationState<String>>(
      'reports no more pages once the first page covers the total',
      setUp: () => printTestDivider(
        'fetchInitial reports no more pages once the first page covers the total',
      ),
      build: () =>
          _TestPaginationCubit((_) async => page(['a', 'b'], total: 2)),
      act: (cubit) => cubit.fetchInitial(),
      expect: () => [
        isA<PaginationLoading<String>>(),
        isA<PaginationLoaded<String>>().having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<_TestPaginationCubit, PaginationState<String>>(
      'emits [Loading, Error] with the API message',
      setUp: () => printTestDivider('fetchInitial emits [Loading, Error] with the API message'),
      build: () => _TestPaginationCubit(
        (_) async => throw const ApiException(message: 'Orders unavailable'),
      ),
      act: (cubit) => cubit.fetchInitial(),
      expect: () => [
        isA<PaginationLoading<String>>(),
        isA<PaginationError<String>>().having(
          (s) => s.message,
          'message',
          'Orders unavailable',
        ),
      ],
    );

    blocTest<_TestPaginationCubit, PaginationState<String>>(
      'emits a generic Error for an unexpected failure',
      setUp: () => printTestDivider('fetchInitial emits a generic Error for an unexpected failure'),
      build: () => _TestPaginationCubit((_) async => throw Exception('boom')),
      act: (cubit) => cubit.fetchInitial(),
      expect: () => [
        isA<PaginationLoading<String>>(),
        isA<PaginationError<String>>().having(
          (s) => s.message,
          'message is a non-empty fallback',
          isNotEmpty,
        ),
      ],
    );

    test('drops a superseded response instead of overwriting newer state', () async {
      printTestDivider('fetchInitial drops a superseded response instead of overwriting newer state');
      // The classic race: an unfiltered load still in flight when a filter is
      // applied. The stale response must not clobber the newer one.
      final firstCall = Completer<PaginatedResponse<String>>();
      final secondCall = Completer<PaginatedResponse<String>>();
      var callCount = 0;

      final cubit = _TestPaginationCubit((_) {
        callCount++;
        return callCount == 1 ? firstCall.future : secondCall.future;
      });

      final first = cubit.fetchInitial();
      final second = cubit.fetchInitial();

      // Newer response lands first, then the stale one completes.
      secondCall.complete(page(['new'], total: 1));
      await second;
      firstCall.complete(page(['stale'], total: 1));
      await first;

      final state = cubit.state as PaginationLoaded<String>;
      printTestLog('data → expected: ["new"], actual: ${state.data}');
      expect(state.data, ['new']);
      await cubit.close();
    });
  });

  group('fetchMore', () {
    test('appends the next page and asks for the right offset', () async {
      printTestDivider('fetchMore appends the next page and asks for the right offset');
      final cubit = _TestPaginationCubit(
        (offset) async => offset == 0
            ? page(['a', 'b'], total: 4)
            : page(['c', 'd'], total: 4),
      );

      await cubit.fetchInitial();
      await cubit.fetchMore();

      final state = cubit.state as PaginationLoaded<String>;
      printTestLog('data → expected: [a, b, c, d], actual: ${state.data}');
      expect(state.data, ['a', 'b', 'c', 'd']);
      // The second page is requested from the count already held, not page 2.
      printTestLog('offsets → expected: [0, 2], actual: ${cubit.requestedOffsets}');
      expect(cubit.requestedOffsets, [0, 2]);
      printTestLog('hasMore → expected: false, actual: ${state.hasMore}');
      expect(state.hasMore, isFalse);
      await cubit.close();
    });

    test('flags isFetchingMore while the next page is in flight', () async {
      printTestDivider('fetchMore flags isFetchingMore while the next page is in flight');
      final nextPage = Completer<PaginatedResponse<String>>();
      final cubit = _TestPaginationCubit(
        (offset) async =>
            offset == 0 ? page(['a'], total: 3) : await nextPage.future,
      );

      await cubit.fetchInitial();
      final pending = cubit.fetchMore();

      var state = cubit.state as PaginationLoaded<String>;
      printTestLog('isFetchingMore while loading → expected: true, actual: ${state.isFetchingMore}');
      expect(state.isFetchingMore, isTrue);
      // The already-loaded rows stay on screen while the next page loads.
      printTestLog('data during load → expected: ["a"], actual: ${state.data}');
      expect(state.data, ['a']);

      nextPage.complete(page(['b'], total: 3));
      await pending;

      state = cubit.state as PaginationLoaded<String>;
      printTestLog('isFetchingMore after → expected: false, actual: ${state.isFetchingMore}');
      expect(state.isFetchingMore, isFalse);
      await cubit.close();
    });

    test('does nothing before the first page has loaded', () async {
      printTestDivider('fetchMore does nothing before the first page has loaded');
      final cubit = _TestPaginationCubit((_) async => page(['a'], total: 1));

      await cubit.fetchMore();

      printTestLog('offsets → expected: [], actual: ${cubit.requestedOffsets}');
      expect(cubit.requestedOffsets, isEmpty);
      printTestLog('state → expected: PaginationInitial, actual: ${cubit.state.runtimeType}');
      expect(cubit.state, isA<PaginationInitial<String>>());
      await cubit.close();
    });

    test('does nothing once every page has been loaded', () async {
      printTestDivider('fetchMore does nothing once every page has been loaded');
      final cubit = _TestPaginationCubit((_) async => page(['a'], total: 1));

      await cubit.fetchInitial();
      await cubit.fetchMore();

      printTestLog('offsets → expected: [0], actual: ${cubit.requestedOffsets}');
      expect(cubit.requestedOffsets, [0]);
      await cubit.close();
    });

    test('ignores a second call while one is already in flight', () async {
      printTestDivider('fetchMore ignores a second call while one is already in flight');
      // Guards against a scroll listener firing repeatedly near the bottom.
      final nextPage = Completer<PaginatedResponse<String>>();
      final cubit = _TestPaginationCubit(
        (offset) async =>
            offset == 0 ? page(['a'], total: 5) : await nextPage.future,
      );

      await cubit.fetchInitial();
      final first = cubit.fetchMore();
      await cubit.fetchMore();

      printTestLog('offsets → expected: [0, 1], actual: ${cubit.requestedOffsets}');
      expect(cubit.requestedOffsets, [0, 1]);

      nextPage.complete(page(['b'], total: 5));
      await first;
      await cubit.close();
    });

    test('surfaces an error but keeps the rows already loaded', () async {
      printTestDivider('fetchMore surfaces an error but keeps the rows already loaded');
      final emitted = <PaginationState<String>>[];
      final cubit = _TestPaginationCubit(
        (offset) async => offset == 0
            ? page(['a'], total: 5)
            : throw const ApiException(message: 'Next page failed'),
      );
      final sub = cubit.stream.listen(emitted.add);

      await cubit.fetchInitial();
      await cubit.fetchMore();

      // The spinner is cleared before the error is surfaced, so the list isn't
      // left showing a stuck footer loader.
      final loadedAfterFailure = emitted.whereType<PaginationLoaded<String>>().last;
      printTestLog(
        'isFetchingMore cleared → expected: false, actual: ${loadedAfterFailure.isFetchingMore}',
      );
      expect(loadedAfterFailure.isFetchingMore, isFalse);
      printTestLog('final state → expected: PaginationError, actual: ${cubit.state.runtimeType}');
      expect(cubit.state, isA<PaginationError<String>>());

      await sub.cancel();
      await cubit.close();
    });
  });

  group('refresh', () {
    test('reloads from the first page', () async {
      printTestDivider('refresh reloads from the first page');
      var callCount = 0;
      final cubit = _TestPaginationCubit((offset) async {
        callCount++;
        return page(['row$callCount'], total: 2);
      });

      await cubit.fetchInitial();
      await cubit.fetchMore();
      await cubit.refresh();

      final state = cubit.state as PaginationLoaded<String>;
      printTestLog('data → expected: single fresh row, actual: ${state.data}');
      expect(state.data, ['row3']);
      printTestLog('last offset → expected: 0, actual: ${cubit.requestedOffsets.last}');
      expect(cubit.requestedOffsets.last, 0);
      await cubit.close();
    });
  });

  group('FilteredPaginationCubit', () {
    test('re-fetches from offset 0 with the new filters', () async {
      printTestDivider('applyFilters re-fetches from offset 0 with the new filters');
      final cubit = _TestFilteredCubit(
        (query, offset) async => page(['$query-$offset'], total: 10),
      );

      await cubit.fetchInitial();
      await cubit.fetchMore();
      await cubit.applyFilters((query: 'pending'));

      printTestLog('requests → expected: last is (pending, 0), actual: ${cubit.requests}');
      expect(cubit.requests.last, (query: 'pending', offset: 0));
      printTestLog('currentFilters → expected: pending, actual: ${cubit.currentFilters.query}');
      expect(cubit.currentFilters.query, 'pending');

      final state = cubit.state as PaginationLoaded<String>;
      // The previous filter's rows are replaced, not appended to.
      printTestLog('data → expected: ["pending-0"], actual: ${state.data}');
      expect(state.data, ['pending-0']);
      await cubit.close();
    });

    test('keeps paging with the active filters', () async {
      printTestDivider('fetchMore keeps paging with the active filters');
      final cubit = _TestFilteredCubit(
        (query, offset) async => page(['$query-$offset'], total: 10),
      );

      await cubit.applyFilters((query: 'delivered'));
      await cubit.fetchMore();

      printTestLog('requests → expected: both with "delivered", actual: ${cubit.requests}');
      expect(cubit.requests, [
        (query: 'delivered', offset: 0),
        (query: 'delivered', offset: 1),
      ]);
      await cubit.close();
    });
  });
}
