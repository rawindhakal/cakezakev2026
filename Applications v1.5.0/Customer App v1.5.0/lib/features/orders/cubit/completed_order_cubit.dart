import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';
import 'ongoing_order_cubit.dart' show OrderFilter;

class CompletedOrderCubit
    extends FilteredPaginationCubit<OrderData, OrderFilter> {
  final OrderRepository _repository;

  CompletedOrderCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(const OrderFilter());

  @override
  PaginationFetcher<OrderData> buildFetcher(OrderFilter filters) {
    return (offset) async {
      final result = await _repository.getCompletedOrders(
        offset: offset,
        channel: filters.channel,
        startDate: filters.startDate,
        endDate: filters.endDate,
      );
      return PaginatedResponse(
        data: result.data ?? [],
        total: result.total ?? 0,
      );
    };
  }

  /// Inserts a just-cancelled order at the top locally — no refetch.
  void addOrder(OrderData order) {
    final current = state;
    if (current is PaginationLoaded<OrderData>) {
      if (current.data.any((o) => o.id == order.id)) return;
      emit(
        current.copyWith(
          data: [order, ...current.data],
          total: current.total + 1,
        ),
      );
      return;
    }
    emit(PaginationLoaded<OrderData>(data: [order], total: 1));
  }

  /// Patches a returned item in place (already in this list) — no refetch.
  void patchOrder(OrderData order) {
    final current = state;
    if (current is! PaginationLoaded<OrderData>) {
      emit(PaginationLoaded<OrderData>(data: [order], total: 1));
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
