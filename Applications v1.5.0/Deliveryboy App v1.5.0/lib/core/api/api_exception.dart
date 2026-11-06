import 'package:dio/dio.dart';

import '../localization/language_label_key.dart';
import '../localization/services/localization_service.dart';
import '../utils/app_logger.dart';

String _t(String key) => LocalizationService.instance.translate(key);

/// Normalized exception thrown for all API/network failures, carrying a user-facing message and optional status code.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  @override
  String toString() => message;

  /// Factory constructor to handle Dio and other exceptions
  factory ApiException.fromDioError(Object error) {
    // Handle Dio exceptions
    if (error is DioException) {
      return ApiException._handleDioException(error);
    }

    // Handle other exceptions — keep raw detail in debug logs only,
    // never surface it to the user.
    logDebug(() => 'ApiException.fromDioError: unhandled error: $error');
    return ApiException(message: _t(LanguageLabelKeys.unexpectedError));
  }

  /// Handles Dio-specific errors
  static ApiException _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return ApiException(message: _t(LanguageLabelKeys.connectionTimeout));

      case DioExceptionType.sendTimeout:
        return ApiException(message: _t(LanguageLabelKeys.requestTimeout));

      case DioExceptionType.receiveTimeout:
        return ApiException(message: _t(LanguageLabelKeys.responseTimeout));

      case DioExceptionType.badCertificate:
        return ApiException(
          message: _t(LanguageLabelKeys.invalidSslCertificate),
        );

      case DioExceptionType.badResponse:
        return ApiException(
          message: _extractErrorMessage(error.response),
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.cancel:
        return ApiException(message: _t(LanguageLabelKeys.requestCancelled));

      case DioExceptionType.connectionError:
        return ApiException(
          message: _t(LanguageLabelKeys.noInternetConnection),
        );

      default:
        return ApiException(message: _t(LanguageLabelKeys.unexpectedError));
    }
  }

  /// Extract error message from API response
  static String _extractErrorMessage(Response? response) {
    if (response?.data == null) {
      return _t(LanguageLabelKeys.somethingWentWrong);
    }

    final data = response!.data;

    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          _t(LanguageLabelKeys.somethingWentWrong);
    }

    return _t(LanguageLabelKeys.somethingWentWrong);
  }
}
