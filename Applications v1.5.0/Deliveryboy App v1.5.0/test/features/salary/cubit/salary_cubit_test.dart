import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/models/paginated_response.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/features/salary/cubit/salary_cubit.dart';
import 'package:deliveryboy/features/salary/models/salary_model.dart';

import '../../../helpers/mock_salary_repository.dart';
import '../../../helpers/test_logging.dart';

/// SalaryCubit is a plain BasePaginationCubit with no filters at all — the
/// base's pagination mechanics (offsets, appending, hasMore, the
/// stale-response guard) are covered once in
/// test/commons/cubit/base_pagination_cubit_test.dart, so these tests focus
/// only on what SalaryCubit adds: fetcher wiring to the repository and the
/// loadSalaries/loadMore aliases.
void main() {
  late MockSalaryRepository repository;

  setUp(() => repository = MockSalaryRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  PaginatedResponse<SalaryModel> page(List<SalaryModel> data, int total) =>
      PaginatedResponse(data: data, total: total);

  SalaryModel entry(int id) => SalaryModel.fromJson({'id': id});

  test('loadSalaries fetches the first page at offset 0', () async {
    printTestDivider('SalaryCubit loadSalaries fetches the first page at offset 0');
    when(
      () => repository.getSalaries(offset: any(named: 'offset')),
    ).thenAnswer((_) async => page([entry(1)], 1));
    final cubit = SalaryCubit(repository: repository);

    await cubit.loadSalaries();

    verify(() => repository.getSalaries(offset: 0)).called(1);
    printTestLog(
      'state → expected: PaginationLoaded, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<PaginationLoaded<SalaryModel>>());
    await cubit.close();
  });

  test('loadMore fetches the next page from the offset already held', () async {
    printTestDivider(
      'SalaryCubit loadMore fetches the next page from the offset already held',
    );
    when(() => repository.getSalaries(offset: 0)).thenAnswer(
      (_) async => page([entry(1), entry(2)], 4),
    );
    when(() => repository.getSalaries(offset: 2)).thenAnswer(
      (_) async => page([entry(3), entry(4)], 4),
    );
    final cubit = SalaryCubit(repository: repository);

    await cubit.loadSalaries();
    await cubit.loadMore();

    verify(() => repository.getSalaries(offset: 2)).called(1);
    final state = cubit.state as PaginationLoaded<SalaryModel>;
    printTestLog(
      'data length → expected: 4, actual: ${state.data.length}',
    );
    expect(state.data.length, 4);
    printTestLog('hasMore → expected: false, actual: ${state.hasMore}');
    expect(state.hasMore, isFalse);
    await cubit.close();
  });

  test('surfaces the API message when the list fails', () async {
    printTestDivider('SalaryCubit surfaces the API message when the list fails');
    when(
      () => repository.getSalaries(offset: any(named: 'offset')),
    ).thenThrow(const ApiException(message: 'Salary payments unavailable'));
    final cubit = SalaryCubit(repository: repository);

    await cubit.loadSalaries();

    final state = cubit.state as PaginationError<SalaryModel>;
    printTestLog(
      'message → expected: "Salary payments unavailable", actual: "${state.message}"',
    );
    expect(state.message, 'Salary payments unavailable');
    await cubit.close();
  });
}
