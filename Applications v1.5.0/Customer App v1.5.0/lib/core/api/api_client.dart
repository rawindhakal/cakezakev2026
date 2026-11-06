import 'package:dio/dio.dart';
import 'package:dio_curl_logger/dio_curl_logger.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:flutter/foundation.dart';
import '../local_storage/settings_hive_box.dart';
import 'api_exception.dart';
import 'dio_interceptor.dart';
import 'etag_interceptor.dart';

class ApiClient {
  late final Dio _dio;

  // Singleton instance
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  /// Centralized Dio instance for third-party/external calls (e.g. Stripe,
  /// file downloads) that must not carry the app's baseUrl or auth header.
  static final Dio external = _buildExternalDio();

  static Dio _buildExternalDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        // Time between data events, not total duration — safe for large
        // downloads as long as data keeps flowing.
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

  Options _withLangHeader([Options? options]) {
    final lang = SettingsHiveBox.instance.languageCode;
    final base = options ?? Options();
    return base.copyWith(
      headers: {
        'Content-Language': lang.isNotEmpty
            ? lang
            : AppConfig.defaultLanguageCode,
        ...?base.headers,
      },
    );
  }

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
        options: _withLangHeader(options),
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
        options: _withLangHeader(options),
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
        options: _withLangHeader(),
      );
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) return response.data;
      throw ApiException(
        message:
            response.statusMessage ??
            LocalizationService.instance.translate(
              LanguageLabelKeys.somethingWentWrong,
            ),
        statusCode: code,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST that returns raw bytes (e.g. a generated PDF) instead of JSON —
  /// bypasses [_handleResponse]'s JSON status-envelope check since the body
  /// isn't `{status, message, data}`.
  Future<List<int>> postBytes(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post<List<int>>(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: _withLangHeader(Options(responseType: ResponseType.bytes)),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data ?? const [];
      }
      throw ApiException(
        message:
            response.statusMessage ??
            LocalizationService.instance.translate(
              LanguageLabelKeys.somethingWentWrong,
            ),
        statusCode: response.statusCode,
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
                data['message'] ??
                LocalizationService.instance.translate(
                  LanguageLabelKeys.somethingWentWrong,
                ),
            statusCode: response.statusCode,
            messageStatusCode: data['status_code']?.toString(),
            responseData: data,
          );
        }
      } else {
        throw ApiException(
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
          statusCode: response.statusCode,
        );
      }
    } else {
      throw ApiException(
        message:
            response.statusMessage ??
            LocalizationService.instance.translate(
              LanguageLabelKeys.somethingWentWrong,
            ),
        statusCode: response.statusCode,
      );
    }
  }

  /// Update Authorization Token
  void setAuthToken(String token) {
    _dio.options.headers["Authorization"] = "Bearer $token";
  }

  /// Remove Authorization Token
  void clearAuthToken() {
    _dio.options.headers.remove("Authorization");
  }
}
