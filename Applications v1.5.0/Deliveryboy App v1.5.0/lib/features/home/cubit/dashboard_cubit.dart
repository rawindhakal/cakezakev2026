import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/home/repositories/dashboard_repository.dart';
import '../models/dashboard_model.dart';

// ── States ──────────────────────────────────────────────────────────────────
typedef DashboardState = AsyncState<DashboardModel>;
typedef DashboardInitial = AsyncInitial<DashboardModel>;
typedef DashboardLoading = AsyncLoading<DashboardModel>;
typedef DashboardLoaded = AsyncLoaded<DashboardModel>;
typedef DashboardError = AsyncError<DashboardModel>;

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Loads the delivery boy's home dashboard summary data.
class DashboardCubit extends BaseAsyncCubit<DashboardModel> {
  final DashboardRepository _repository;

  DashboardCubit({DashboardRepository? repository})
    : _repository = repository ?? DashboardRepository();

  /// Fetches the dashboard data from the server.
  /// [trend] selects the earnings-trend window: "7", "30", "90", or "12m".
  Future<void> getDashboard({String trend = '7'}) =>
      run(() => _repository.getDashboard(trend: trend));
}
