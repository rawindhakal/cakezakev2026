import 'package:dio/dio.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:flutter/foundation.dart';
import '../local_storage/auth_hive_box.dart';
import '../local_storage/settings_hive_box.dart';
import 'api_endpoints.dart';

/// Callback to be called on 401 unauthorized error
typedef OnUnauthorizedCallback = void Function();

/// Dio interceptor that attaches auth/language headers, logs in debug mode, and handles 401 auto-logout.
class DioInterceptor extends Interceptor {
  static const _noAuthEndpoints = {
    ApiEndpoints.login,
    ApiEndpoints.register,
    ApiEndpoints.forgotPassword,
  };

  /// Static callback to handle unauthorized (401) errors
  static OnUnauthorizedCallback? onUnauthorized;

  /// Set callback for 401 handling
  static void setOnUnauthorizedCallback(OnUnauthorizedCallback callback) {
    onUnauthorized = callback;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final isPublic = _noAuthEndpoints.any((e) => options.path.contains(e));
    if (!isPublic) {
      final token = AuthHiveBox.instance.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    final langCode = SettingsHiveBox.instance.languageCode;
    options.headers['Content-Language'] = langCode.isNotEmpty
        ? langCode
        : AppConfig.defaultLanguageCode;

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        'RESPONSE[${response.statusCode}] => ${response.requestOptions.path}',
      );
      debugPrint('DATA: ${response.data}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('ERROR[${err.response?.statusCode}] => ${err.message}');
    }

    // Handle 401 Unauthorized - Auto logout and clear session
    if (err.response?.statusCode == 401) {
      _handleUnauthorized();
    }

    handler.next(err);
  }

  /// Handle unauthorized error - clear session and notify
  void _handleUnauthorized() {
    // Clear auth data from local storage
    AuthHiveBox.instance.clearAuth();

    // Notify the app to navigate to login
    if (onUnauthorized != null) {
      onUnauthorized!();
    }
  }
}
