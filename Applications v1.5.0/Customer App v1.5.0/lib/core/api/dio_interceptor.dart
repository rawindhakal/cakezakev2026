import 'package:dio/dio.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:flutter/foundation.dart';
import '../local_storage/auth_hive_box.dart';
import '../local_storage/settings_hive_box.dart';
import 'api_endpoints.dart';

/// Callback to be called on 401 unauthorized error
typedef OnUnauthorizedCallback = void Function();

class DioInterceptor extends Interceptor {
  static const _noAuthEndpoints = {
    ApiEndpoints.login,
    ApiEndpoints.register,
    ApiEndpoints.forgotPassword,
  };

  static const _requiresAuthEndpoints = {
    ApiEndpoints.favorite,
    ApiEndpoints.addProductToFavorite,
    ApiEndpoints.removeProductFromFavorite,
    ApiEndpoints.paymentMethodsSettings,
    ApiEndpoints.editProfile,
    ApiEndpoints.userDetails,
    ApiEndpoints.ratingAdd,
    ApiEndpoints.ratingUpdate,
    ApiEndpoints.cartAdd,
    ApiEndpoints.cartRemove,
    ApiEndpoints.guestCartBulkAddToCartWhileLogin,
    ApiEndpoints.ordersHistory,
    ApiEndpoints.promoCode,
    ApiEndpoints.promoCodeValidate,
    ApiEndpoints.address,
    ApiEndpoints.addressAdd,
    ApiEndpoints.addressUpdate,
    ApiEndpoints.addressRemove,
    ApiEndpoints.placeOrder,
    ApiEndpoints.initiateTransaction,
    ApiEndpoints.addTransaction,
    ApiEndpoints.deleteAccount,
    ApiEndpoints.transaction,
    ApiEndpoints.notificationPreferences,
    ApiEndpoints.downloadOrderInvoice,
    ApiEndpoints.paytmTransactionToken,
    ApiEndpoints.deleteOrder,
    ApiEndpoints.orderStatusPhonepe,
    ApiEndpoints.logout,
    ApiEndpoints.sendChatMessage,
  };

  /// Static callback to handle unauthorized (401) errors
  static OnUnauthorizedCallback? onUnauthorized;

  /// Set callback for 401 handling
  static void setOnUnauthorizedCallback(OnUnauthorizedCallback callback) {
    onUnauthorized = callback;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requiresAuth = _requiresAuthEndpoints.any(
      (e) => options.path.contains(e),
    );
    if (requiresAuth && !AuthHiveBox.instance.isLoggedIn) {
      _handleUnauthorized();
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Authentication required. Please login.',
        ),
      );
      return;
    }

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

    // A caller may pin the channel for one request (e.g. the zone picker
    // geocoding with a not-yet-saved zone channel); otherwise use the session.
    options.headers['channel'] ??= SettingsHiveBox.instance.channel;

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
