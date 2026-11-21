// file: api_exceptions.dart

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException([super.message = 'No internet connection']);
}

class TimeoutException extends ApiException {
  TimeoutException([super.message = 'Connection timed out. Please try again.']);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([
    super.message = 'Unauthorized access. Please login again.',
    super.statusCode,
  ]);
}

/// 4xx bodies now carry the real `message`. 5xx and network stay on [fallback].
String clientErrorMessage(
  Object error, [
  String fallback = 'Something went wrong',
]) {
  if (error is! ApiException) return fallback;
  final code = error.statusCode ?? 0;
  final text = error.message.trim();
  if (text.isEmpty) return fallback;
  if (error is UnauthorizedException ||
      error is ValidationException ||
      error is NotFoundException ||
      (code >= 400 && code < 500)) {
    return text;
  }
  return fallback;
}

class ValidationException extends ApiException {
  ValidationException(super.message,[super.statusCode]);
}

class ServerException extends ApiException {
  ServerException([super.message = 'Internal server error occurred.']);
}

class NotFoundException extends ApiException {
  NotFoundException([super.message = 'Requested resource not found.']);
}