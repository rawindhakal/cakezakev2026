import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/models/paginated_response.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';

/// Filter params for ongoing/completed order pagination (channel + date range).
class OrderFilter {
  final String? channel;
  final String? startDate;
  final String? endDate;

  const OrderFilter({this.channel, this.startDate, this.endDate});
}

class OngoingOrderCubit
    extends FilteredPaginationCubit<OrderData, OrderFilter> {
  final OrderRepository _repository;

  OngoingOrderCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(const OrderFilter());

  @override
  PaginationFetcher<OrderData> buildFetcher(OrderFilter filters) {
    return (offset) async {
      final result = await _repository.getOngoingOrders(
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

  /// Drops a cancelled order from the ongoing list locally — no refetch.
  void removeOrder(String orderId) {
    final current = state;
    if (current is! PaginationLoaded<OrderData>) return;
    final orders = current.data
        .where((o) => o.id?.toString() != orderId)
        .toList();
    if (orders.length == current.data.length) return;
    emit(
      current.copyWith(
        data: orders,
        total: current.total > 0 ? current.total - 1 : 0,
      ),
    );
  }
}
