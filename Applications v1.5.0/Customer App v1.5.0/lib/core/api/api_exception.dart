import 'package:dio/dio.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? messageStatusCode;
  final bool isCancelled;

  /// Raw body of an HTTP 200 / `status: 0` reply, for endpoints that still
  /// carry usable fields alongside the failure (e.g. zone's
  /// `channels_available`).
  final Map<String, dynamic>? responseData;

  const ApiException({
    required this.message,
    this.statusCode,
    this.messageStatusCode,
    this.isCancelled = false,
    this.responseData,
  });

  @override
  String toString() => message;

  /// Factory constructor to handle Dio and other exceptions
  factory ApiException.fromDioError(Object error) {
    // Handle Dio exceptions
    if (error is DioException) {
      return ApiException._handleDioException(error);
    }

    // Handle other exceptions
    return ApiException(message: error.toString());
  }

  /// Handles Dio-specific errors
  static ApiException _handleDioException(DioException error) {
    final t = LocalizationService.instance.translate;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(message: t(LanguageLabelKeys.connectionTimeout));

      case DioExceptionType.badCertificate:
        return ApiException(message: t(LanguageLabelKeys.somethingWentWrong));

      case DioExceptionType.badResponse:
        final code = error.response?.statusCode ?? 0;
        if (code >= 500) {
          return ApiException(
            message: t(LanguageLabelKeys.somethingWentWrong),
            statusCode: code,
          );
        }
        return ApiException(
          message: _extractErrorMessage(error.response),
          statusCode: code,
        );

      case DioExceptionType.cancel:
        return ApiException(message: t(LanguageLabelKeys.requestCancelled));

      case DioExceptionType.connectionError:
        return ApiException(message: t(LanguageLabelKeys.noInternet));

      default:
        return ApiException(message: t(LanguageLabelKeys.somethingWentWrong));
    }
  }

  /// Extract error message from API response
  static String _extractErrorMessage(Response? response) {
    final fallback = LocalizationService.instance.translate(
      LanguageLabelKeys.somethingWentWrong,
    );
    if (response?.data == null) {
      return fallback;
    }

    final data = response!.data;

    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          fallback;
    }

    return fallback;
  }
}
