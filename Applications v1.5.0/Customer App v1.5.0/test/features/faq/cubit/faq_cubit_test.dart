import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/faq/cubit/faq_cubit.dart';
import 'package:customer/features/faq/models/faq_model.dart';

import '../../../helpers/mock_faq_repository.dart';
import '../../../helpers/test_logging.dart';

/// FaqCubit is a plain BasePaginationCubit with no aliases of its own (it's
/// driven directly via the base's fetchInitial/fetchMore/refresh) — the
/// base's pagination mechanics are covered once in
/// test/commons/cubit/base_pagination_cubit_test.dart, so these tests focus
/// only on what FaqCubit adds: wiring its fetcher to FaqRepository.getFaqs
/// and turning the response's string `total` into an int.
void main() {
  late MockFaqRepository repository;

  setUp(() => repository = MockFaqRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  FaqData entry(String id) => FaqData.fromJson({'id': id, 'question': 'q$id'});

  test('fetchInitial fetches offset 0 and maps data/total from the response', () async {
    printTestDivider(
      'FaqCubit fetchInitial fetches offset 0 and maps data/total from the response',
    );
    when(() => repository.getFaqs(offset: any(named: 'offset'))).thenAnswer(
      (_) async => FaqResponse(
        status: '1',
        total: '5',
        data: [entry('1'), entry('2')],
      ),
    );
    final cubit = FaqCubit(repository: repository);

    await cubit.fetchInitial();

    verify(() => repository.getFaqs(offset: 0)).called(1);
    final state = cubit.state as PaginationLoaded<FaqData>;
    printTestLog('data length → expected: 2, actual: ${state.data.length}');
    expect(state.data.length, 2);
    printTestLog('total → expected: 5, actual: ${state.total}');
    expect(state.total, 5);
    await cubit.close();
  });

  test('a null response total falls back to 0 rather than crashing', () async {
    printTestDivider(
      'FaqCubit a null response total falls back to 0 rather than crashing',
    );
    when(() => repository.getFaqs(offset: any(named: 'offset'))).thenAnswer(
      (_) async => FaqResponse(status: '1', total: null, data: []),
    );
    final cubit = FaqCubit(repository: repository);

    await cubit.fetchInitial();

    final state = cubit.state as PaginationLoaded<FaqData>;
    printTestLog('total → expected: 0, actual: ${state.total}');
    expect(state.total, 0);
    await cubit.close();
  });

  test('a null response data falls back to an empty list', () async {
    printTestDivider('FaqCubit a null response data falls back to an empty list');
    when(() => repository.getFaqs(offset: any(named: 'offset'))).thenAnswer(
      (_) async => FaqResponse(status: '1', total: '0', data: null),
    );
    final cubit = FaqCubit(repository: repository);

    await cubit.fetchInitial();

    final state = cubit.state as PaginationLoaded<FaqData>;
    printTestLog('data → expected: [], actual: ${state.data}');
    expect(state.data, isEmpty);
    await cubit.close();
  });

  test('fetchMore fetches the next page from the offset already held', () async {
    printTestDivider(
      'FaqCubit fetchMore fetches the next page from the offset already held',
    );
    when(() => repository.getFaqs(offset: 0)).thenAnswer(
      (_) async =>
          FaqResponse(status: '1', total: '4', data: [entry('1'), entry('2')]),
    );
    when(() => repository.getFaqs(offset: 2)).thenAnswer(
      (_) async =>
          FaqResponse(status: '1', total: '4', data: [entry('3'), entry('4')]),
    );
    final cubit = FaqCubit(repository: repository);

    await cubit.fetchInitial();
    await cubit.fetchMore();

    verify(() => repository.getFaqs(offset: 2)).called(1);
    final state = cubit.state as PaginationLoaded<FaqData>;
    printTestLog('data length → expected: 4, actual: ${state.data.length}');
    expect(state.data.length, 4);
    printTestLog('hasMore → expected: false, actual: ${state.hasMore}');
    expect(state.hasMore, isFalse);
    await cubit.close();
  });

  test('surfaces the API message when the list fails', () async {
    printTestDivider('FaqCubit surfaces the API message when the list fails');
    when(
      () => repository.getFaqs(offset: any(named: 'offset')),
    ).thenThrow(const ApiException(message: 'Faqs unavailable'));
    final cubit = FaqCubit(repository: repository);

    await cubit.fetchInitial();

    final state = cubit.state as PaginationError<FaqData>;
    printTestLog(
      'message → expected: "Faqs unavailable", actual: "${state.message}"',
    );
    expect(state.message, 'Faqs unavailable');
    await cubit.close();
  });
}
