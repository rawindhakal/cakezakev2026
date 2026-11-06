import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import '../models/ecommerce_order_model.dart';
import '../repositories/order_repository.dart';
import 'ongoing_ecommerce_order_cubit.dart' show EcommerceOrderFilter;

class CompletedEcommerceOrderCubit
    extends
        FilteredPaginationCubit<EcommerceOrderDataModel, EcommerceOrderFilter> {
  final OrderRepository _repository;

  CompletedEcommerceOrderCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(const EcommerceOrderFilter());

  @override
  PaginationFetcher<EcommerceOrderDataModel> buildFetcher(
    EcommerceOrderFilter filters,
  ) {
    return (offset) async {
      final result = await _repository.getEcommerceCompletedOrders(
        offset: offset,
        startDate: filters.startDate,
        endDate: filters.endDate,
      );
      return PaginatedResponse(
        data: result.data ?? [],
        total: result.total ?? 0,
      );
    };
  }

  /// Inserts a just-cancelled item at the top locally — no refetch.
  void addOrder(EcommerceOrderDataModel order) {
    final current = state;
    if (current is PaginationLoaded<EcommerceOrderDataModel>) {
      if (current.data.any((o) => o.id == order.id)) return;
      emit(
        current.copyWith(
          data: [order, ...current.data],
          total: current.total + 1,
        ),
      );
      return;
    }
    emit(PaginationLoaded<EcommerceOrderDataModel>(data: [order], total: 1));
  }

  /// Patches a returned item in place (already in this list) — no refetch.
  void patchOrder(EcommerceOrderDataModel order) {
    final current = state;
    if (current is! PaginationLoaded<EcommerceOrderDataModel>) {
      emit(PaginationLoaded<EcommerceOrderDataModel>(data: [order], total: 1));
      return;
    }
    final index = current.data.indexWhere((o) => o.id == order.id);
    if (index == -1) {
      emit(
        current.copyWith(
          data: [order, ...current.data],
          total: current.total + 1,
        ),
      );
      return;
    }
    final orders = [...current.data];
    orders[index] = order;
    emit(current.copyWith(data: orders));
  }
}
