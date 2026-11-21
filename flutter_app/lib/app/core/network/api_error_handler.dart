// file: api_error_handler.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'api_expection.dart';

class ApiErrorHandler {
  /// Extract error message robustly from any API response data
  static String extractErrorMessage(dynamic data) {
    if (data == null) return 'Unknown error occurred';

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map.containsKey('errors') && map['errors'] is Map) {
        final errorsMap = Map<String, dynamic>.from(map['errors'] as Map);
        if (errorsMap.isNotEmpty) {
          final firstKey = errorsMap.keys.first;
          final firstError = errorsMap[firstKey];
          if (firstError is List && firstError.isNotEmpty) {
            return firstError.first.toString();
          }
          return firstError.toString();
        }
      }

      if (map.containsKey('errors') && map['errors'] is List) {
        final errorsList = map['errors'] as List;
        if (errorsList.isNotEmpty) {
          final first = errorsList.first;
          if (first is Map) {
            final field = first['field']?.toString().trim() ?? '';
            final message = first['message']?.toString().trim() ?? '';
            if (message.isEmpty) return first.toString();
            return field.isEmpty ? message : '$field: $message';
          }
          return first.toString();
        }
      }

      if (map['message'] != null) {
        return map['message'].toString();
      }

      if (map['error'] != null) {
        return map['error'].toString();
      }
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return 'Something went wrong';
  }

  /// Convert DioException to Custom Exception
  static ApiException handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException();

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final message = extractErrorMessage(error.response?.data);

        if (statusCode == 401 || statusCode == 403) {
          return UnauthorizedException(message, statusCode);
        }
        if (statusCode >= 400 && statusCode < 500) {
          return ValidationException(message, statusCode);
        }
        if (statusCode >= 500) return ServerException(message);

        return ApiException(message, statusCode);

      case DioExceptionType.connectionError:
        if (error.error is SocketException) {
          return NetworkException();
        }
        return NetworkException('Connection error occurred');

      case DioExceptionType.cancel:
        return ApiException('Request was cancelled');

      default:
        return ApiException('An unexpected error occurred');
    }
  }
}