import 'package:dio/dio.dart';
import 'package:dio_curl_logger/dio_curl_logger.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:flutter/foundation.dart';
import '../localization/language_label_key.dart';
import '../localization/services/localization_service.dart';
import 'api_exception.dart';
import 'dio_interceptor.dart';
import 'etag_interceptor.dart';

String _t(String key) => LocalizationService.instance.translate(key);

/// Singleton Dio wrapper providing GET/POST/upload/download helpers with shared auth, language, and error handling.
class ApiClient {
  late final Dio _dio;

  // Singleton instance
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  /// Centralized Dio instance for third-party/external calls (e.g. OSRM
  /// routing) that must not carry the app's baseUrl or auth header.
  static final Dio external = _buildExternalDio();

  static Dio _buildExternalDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(CurlLoggingInterceptor());
    }
    return dio;
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
        headers: const {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
      ),
    );

    _dio.interceptors.add(DioInterceptor());
    _dio.interceptors.add(ETagInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(CurlLoggingInterceptor());
    }
  }

  /// Test-only seam: swaps the underlying HTTP adapter so integration tests
  /// can serve canned responses without hitting the network. Never called by
  /// app code.
  @visibleForTesting
  set httpClientAdapter(HttpClientAdapter adapter) =>
      _dio.httpClientAdapter = adapter;

  // Content-Language is attached by DioInterceptor.onRequest for every request
  // on this Dio instance, so there's no per-call header helper here. An earlier
  // one duplicated the interceptor on get/post/postRaw and was simply missing
  // from upload/downloadFile, which is what made those two the odd ones out.

  /// Generic GET Method
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Generic POST Method
  Future<dynamic> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST for endpoints outside the app's own API — e.g. Laravel's built-in
  /// `broadcasting/auth` — that return their own raw JSON body instead of
  /// this app's `{status, message, data}` envelope. Only checks the HTTP
  /// status; still goes through the shared Dio instance (auth header,
  /// interceptors, logging).
  Future<dynamic> postRaw(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) return response.data;
      throw ApiException(
        message:
            response.statusMessage ?? _t(LanguageLabelKeys.somethingWentWrong),
        statusCode: code,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// File Upload Method
  Future<dynamic> upload(String endpoint, {required FormData formData}) async {
    try {
      final response = await _dio.post(endpoint, data: formData);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// File Download Method
  Future<void> downloadFile(String url, String savePath) async {
    try {
      await _dio.download(url, savePath);
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Handle API Response
  dynamic _handleResponse(Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;

      // Check API-level status
      if (data is Map<String, dynamic>) {
        final apiStatus = data['status'];

        if (apiStatus == 1) {
          return data; // success
        } else {
          throw ApiException(
            message:
                data['message'] ?? _t(LanguageLabelKeys.somethingWentWrong),
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiException(
          message: _t(LanguageLabelKeys.invalidResponseFormat),
          statusCode: response.statusCode,
        );
      }
    } else {
      throw ApiException(
        message:
            response.statusMessage ?? _t(LanguageLabelKeys.somethingWentWrong),
        statusCode: response.statusCode,
      );
    }
  }

  // No setAuthToken/clearAuthToken here: the Authorization header is attached
  // per-request by DioInterceptor from AuthHiveBox, so there is no Dio-level
  // default header to set or clear. Logout drops the token by calling
  // AuthHiveBox.clearAuth(), after which the interceptor stops sending it.
}
