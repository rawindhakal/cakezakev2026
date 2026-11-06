import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';

/// Fetches the supported countries list and their zones from the backend.
class CountriesRepository {
  final ApiClient _apiClient;

  CountriesRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetches the full list of supported countries.
  Future<Countries> getCountries() async {
    final response = await _apiClient.get(ApiEndpoints.countries);
    return Countries.fromJson(response as Map<String, dynamic>);
  }

  /// Fetches the delivery zones belonging to [countryId].
  Future<Zones> getZones({required String countryId}) async {
    final response = await _apiClient.get(
      ApiEndpoints.zones,
      queryParameters: {ApiParameters.countryId: countryId},
    );
    return Zones.fromJson(response as Map<String, dynamic>);
  }
}
