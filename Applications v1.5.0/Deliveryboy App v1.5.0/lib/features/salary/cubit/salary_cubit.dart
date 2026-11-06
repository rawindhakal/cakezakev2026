import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import '../models/salary_model.dart';
import '../repositories/salary_repository.dart';

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Manages the paginated salary payment history list.
class SalaryCubit extends BasePaginationCubit<SalaryModel> {
  final SalaryRepository _repository;

  SalaryCubit({SalaryRepository? repository})
    : _repository = repository ?? SalaryRepository();

  @override
  PaginationFetcher<SalaryModel> get fetcher =>
      (offset) => _repository.getSalaries(offset: offset);

  // Backward-compatible aliases for existing call sites.
  /// Load the first page of salary payments.
  Future<void> loadSalaries() => fetchInitial();

  /// Load the next page of salary payments.
  Future<void> loadMore() => fetchMore();
}
