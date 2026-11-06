import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/commons/models/zones_model.dart';
import 'package:customer/commons/models/regions_model.dart';

class AddressRepository {
  final ApiClient _apiClient;

  AddressRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<Address> getAddresses({
    int offset = 0,
    int limit = AppConfig.pageLimit,
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
      };
      final response = await _apiClient.get(
        ApiEndpoints.address,
        queryParameters: params,
      );
      return Address.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Parses the single address object returned by add/update.
  /// Response `data` may be a single map or a list — handle both.
  AddressData? _parseAddress(dynamic response) {
    if (response is! Map<String, dynamic>) return null;
    final data = response['data'];
    if (data is List && data.isNotEmpty) {
      return AddressData.fromJson(data.first as Map<String, dynamic>);
    }
    if (data is Map<String, dynamic>) return AddressData.fromJson(data);
    return null;
  }

  /// Adds a new address, or updates an existing one when [isEdit] is true
  /// (in which case [address].id must be set). Returns the saved address
  /// from the response so the list can be updated locally without a
  /// separate get-addresses call. Null if not present.
  Future<AddressData?> saveAddress(
    AddressData address, {
    bool isEdit = false,
  }) async {
    try {
      final response = await _apiClient.post(
        isEdit ? ApiEndpoints.addressUpdate : ApiEndpoints.addressAdd,
        data: address.toJson(),
      );
      final saved = _parseAddress(response);
      // Fall back to the form id if the response omits it.
      return isEdit ? (saved?..id ??= address.id) : saved;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteAddress({required String id}) async {
    try {
      await _apiClient.post(
        ApiEndpoints.addressRemove,
        data: {ApiParameters.id: id},
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> getPlaceAutocomplete({
    required String input,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.googlePlacesAutocomplete,
        queryParameters: {
          ApiParameters.input: input,
          ApiParameters.source: ApiParameters.app,
        },
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> getPlaceDetails({
    required String placeId,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.googlePlacesDetails,
        queryParameters: {
          ApiParameters.placeId: placeId,
          ApiParameters.source: ApiParameters.app,
        },
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// [channel] overrides the session `channel` header for this call only —
  /// null (every existing caller) keeps the session channel.
  Future<Map<String, dynamic>> getGeocodingByLatLng({
    required String latitude,
    required String longitude,
    String? channel,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.googleMapsGeocoding,
        queryParameters: {
          ApiParameters.latitude: latitude,
          ApiParameters.longitude: longitude,
          ApiParameters.source: ApiParameters.app,
        },
        options: channel == null
            ? null
            : Options(headers: {'channel': channel}),
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Countries> getCountries() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.countries);
      return Countries.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> getZone({
    required String latitude,
    required String longitude,
  }) async {
    try {
      final params = <String, dynamic>{
        ApiParameters.latitude: latitude,
        ApiParameters.longitude: longitude,
      };
      final response = await _apiClient.get(
        ApiEndpoints.zone,
        queryParameters: params,
      );
      return response as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetches the delivery zones belonging to [countryId].
  Future<Zones> getZones({required String countryId}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.zones,
        queryParameters: {ApiParameters.countryId: countryId},
      );
      return Zones.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetches the regions (states/provinces) belonging to [countryId].
  Future<Regions> getRegions({required String countryId}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.regions,
        queryParameters: {ApiParameters.countryId: countryId},
      );
      return Regions.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
