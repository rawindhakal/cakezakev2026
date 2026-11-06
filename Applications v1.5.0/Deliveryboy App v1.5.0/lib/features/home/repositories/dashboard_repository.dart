import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';

/// Handles dashboard-related network calls.
class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// GET /dashboard — returns full dashboard response with delivery boy data.
  /// [trend] selects the earnings-trend window: "7", "30", "90", or "12m".
  Future<DashboardModel> getDashboard({String trend = '7'}) async {
    final response = await _apiClient.get(
      ApiEndpoints.dashboard,
      queryParameters: {'trend': trend},
    );
    return DashboardModel.fromJson(response as Map<String, dynamic>);
  }
}
