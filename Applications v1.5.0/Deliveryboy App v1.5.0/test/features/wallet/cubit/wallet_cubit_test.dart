import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/features/wallet/cubit/wallet_cubit.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';

import '../../../helpers/mock_wallet_repository.dart';
import '../../../helpers/test_logging.dart';

/// WalletCubit is a thin filter wrapper over the shared pagination base
/// (covered on its own in test/commons/cubit), so these tests focus on what
/// it adds: which repository call it makes, what it passes, the backward
/// compatible aliases (fetchWalletData/loadMore/search/filterByStatus/
/// loadWallet), the balance getter, and the page-count based hasMore.
void main() {
  late MockWalletRepository repository;

  setUp(() => repository = MockWalletRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  PaginatedResponse<WithdrawRequests> page(
    List<WithdrawRequests> data,
    int total, {
    double? meta,
  }) => PaginatedResponse(data: data, total: total, meta: meta);

  WithdrawRequests entry(String id) =>
      WithdrawRequests.fromJson({'id': id});

  void stubRequests({PaginatedResponse<WithdrawRequests>? response}) {
    when(
      () => repository.getWithdrawalRequests(
        search: any(named: 'search'),
        status: any(named: 'status'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => response ?? page([entry('1')], 1));
  }

  test('loadWallet loads the first page with empty filters', () async {
    printTestDivider('WalletCubit loadWallet loads the first page with empty filters');
    stubRequests();
    final cubit = WalletCubit(repository: repository);

    cubit.loadWallet();
    await Future<void>.delayed(Duration.zero);

    verify(
      () => repository.getWithdrawalRequests(
        search: '',
        status: '',
        offset: 0,
      ),
    ).called(1);
    printTestLog(
      'state → expected: PaginationLoaded, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<PaginationLoaded<WithdrawRequests>>());
    await cubit.close();
  });

  test('search applies the search filter, keeping the current status', () async {
    printTestDivider(
      'WalletCubit search applies the search filter, keeping the current status',
    );
    stubRequests();
    final cubit = WalletCubit(repository: repository);

    await cubit.filterByStatus('1');
    await cubit.search('John');

    verify(
      () => repository.getWithdrawalRequests(
        search: 'John',
        status: '1',
        offset: 0,
      ),
    ).called(1);
    printTestLog('searchQuery → expected: "John", actual: "${cubit.searchQuery}"');
    expect(cubit.searchQuery, 'John');
    printTestLog('selectedStatus → expected: "1", actual: "${cubit.selectedStatus}"');
    expect(cubit.selectedStatus, '1');
    await cubit.close();
  });

  test('filterByStatus applies the status filter, keeping the current search', () async {
    printTestDivider(
      'WalletCubit filterByStatus applies the status filter, keeping the current search',
    );
    stubRequests();
    final cubit = WalletCubit(repository: repository);

    await cubit.search('John');
    await cubit.filterByStatus('2');

    verify(
      () => repository.getWithdrawalRequests(
        search: 'John',
        status: '2',
        offset: 0,
      ),
    ).called(1);
    printTestLog('selectedStatus → expected: "2", actual: "${cubit.selectedStatus}"');
    expect(cubit.selectedStatus, '2');
    await cubit.close();
  });

  test('loadMore pages with the active filters still applied', () async {
    printTestDivider('WalletCubit loadMore pages with the active filters still applied');
    // hasMore is page-count based (data.length >= pageLimit), so the first
    // page must be a full page for loadMore to actually fire a second call.
    final fullPage = List.generate(AppConfig.pageLimit, (i) => entry('$i'));
    stubRequests(response: page(fullPage, 100));
    final cubit = WalletCubit(repository: repository);

    await cubit.search('John');
    await cubit.loadMore();

    verify(
      () => repository.getWithdrawalRequests(
        search: 'John',
        status: '',
        offset: AppConfig.pageLimit,
      ),
    ).called(1);
    await cubit.close();
  });

  group('fetchWalletData backward-compatible alias', () {
    test('with isLoadMore true delegates to fetchMore', () async {
      printTestDivider(
        'WalletCubit fetchWalletData with isLoadMore true delegates to fetchMore',
      );
      final fullPage = List.generate(AppConfig.pageLimit, (i) => entry('$i'));
      stubRequests(response: page(fullPage, 100));
      final cubit = WalletCubit(repository: repository);
      cubit.loadWallet();
      await Future<void>.delayed(Duration.zero);

      await cubit.fetchWalletData(isLoadMore: true);

      verify(
        () => repository.getWithdrawalRequests(
          search: any(named: 'search'),
          status: any(named: 'status'),
          offset: AppConfig.pageLimit,
        ),
      ).called(1);
      await cubit.close();
    });

    test('without isLoadMore applies given search/status, falling back to current', () async {
      printTestDivider(
        'WalletCubit fetchWalletData without isLoadMore applies given search/status, falling back to current',
      );
      stubRequests();
      final cubit = WalletCubit(repository: repository);

      await cubit.fetchWalletData(search: 'Jane', status: '0');

      verify(
        () => repository.getWithdrawalRequests(
          search: 'Jane',
          status: '0',
          offset: 0,
        ),
      ).called(1);

      await cubit.fetchWalletData();

      verify(
        () => repository.getWithdrawalRequests(
          search: 'Jane',
          status: '0',
          offset: 0,
        ),
      ).called(1);
      await cubit.close();
    });
  });

  group('balance getter', () {
    test('reads off the loaded meta', () async {
      printTestDivider('WalletCubit balance getter reads off the loaded meta');
      stubRequests(response: page([entry('1')], 1, meta: 4520.75));
      final cubit = WalletCubit(repository: repository);

      cubit.loadWallet();
      await Future<void>.delayed(Duration.zero);

      printTestLog('balance → expected: 4520.75, actual: ${cubit.balance}');
      expect(cubit.balance, 4520.75);
      await cubit.close();
    });

    test('is 0.0 outside the loaded state', () async {
      printTestDivider('WalletCubit balance getter is 0.0 outside the loaded state');
      final cubit = WalletCubit(repository: repository);

      printTestLog('balance → expected: 0.0, actual: ${cubit.balance}');
      expect(cubit.balance, 0.0);
      await cubit.close();
    });
  });

  test('page-count hasMore stays true while a full page comes back', () async {
    printTestDivider(
      'WalletCubit page-count hasMore stays true while a full page comes back',
    );
    final fullPage = List.generate(AppConfig.pageLimit, (i) => entry('$i'));
    stubRequests(response: page(fullPage, 999));
    final cubit = WalletCubit(repository: repository);

    cubit.loadWallet();
      await Future<void>.delayed(Duration.zero);

    final state = cubit.state as PaginationLoaded<WithdrawRequests>;
    printTestLog('hasMore → expected: true, actual: ${state.hasMore}');
    expect(state.hasMore, isTrue);
    await cubit.close();
  });

  test('page-count hasMore is false once a partial page comes back', () async {
    printTestDivider(
      'WalletCubit page-count hasMore is false once a partial page comes back',
    );
    stubRequests(response: page([entry('1')], 999));
    final cubit = WalletCubit(repository: repository);

    cubit.loadWallet();
      await Future<void>.delayed(Duration.zero);

    final state = cubit.state as PaginationLoaded<WithdrawRequests>;
    printTestLog('hasMore → expected: false, actual: ${state.hasMore}');
    expect(state.hasMore, isFalse);
    await cubit.close();
  });

  test('surfaces the API message when the list fails', () async {
    printTestDivider('WalletCubit surfaces the API message when the list fails');
    when(
      () => repository.getWithdrawalRequests(
        search: any(named: 'search'),
        status: any(named: 'status'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(const ApiException(message: 'Wallet unavailable'));
    final cubit = WalletCubit(repository: repository);

    cubit.loadWallet();
      await Future<void>.delayed(Duration.zero);

    final state = cubit.state as PaginationError<WithdrawRequests>;
    printTestLog('message → expected: "Wallet unavailable", actual: "${state.message}"');
    expect(state.message, 'Wallet unavailable');
    await cubit.close();
  });
}
