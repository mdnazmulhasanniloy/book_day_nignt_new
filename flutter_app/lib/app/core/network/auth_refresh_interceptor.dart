import 'package:dio/dio.dart';

import 'auth_refresh_coordinator.dart';
import 'end_point.dart';

/// Thin Dio interceptor around [AuthRefreshCoordinator].
///
/// BaseClient uses `validateStatus: (_) => true`, so a 401 arrives as a normal
/// response; this is why it hooks `onResponse` and not `onError`.
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({required this.dio, required this.coordinator});

  /// The Dio that owns this interceptor; used to resend the request.
  final Dio dio;
  final AuthRefreshCoordinator coordinator;

  static const retriedKey = 'retried';

  /// A 401 on these means wrong credentials or a bad code, not an expired
  /// session.
  static const skippedPaths = <String>[
    EndPoint.LOGIN,
    EndPoint.CREATE_ACCOUNT,
    EndPoint.VERIFY_EMAIL,
    EndPoint.RESEND_OTP,
    EndPoint.socialLogin,
    EndPoint.GOOGLE_LOGIN,
    EndPoint.REFRESH,
    EndPoint.LOGOUT,
    '/recover/',
  ];

  static bool isSkippedPath(String path) =>
      skippedPaths.any((p) => path.contains(p));

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    if (response.statusCode != 401 ||
        options.extra[retriedKey] == true ||
        isSkippedPath(options.path) ||
        !coordinator.hasSession) {
      return handler.next(response);
    }

    final sent = _bearer(options.headers['Authorization']);
    if (sent == null) {
      // The request carried no token (public call): not a session problem.
      return handler.next(response);
    }

    final newToken = await coordinator.refresh(failedAccessToken: sent);
    if (newToken == null) return handler.next(response);

    // A consumed FormData body (or a download stream) cannot be resent. The
    // tokens are fresh now, so the caller's own retry will succeed.
    if (options.data is FormData || options.responseType == ResponseType.stream) {
      return handler.next(response);
    }

    try {
      final retry = options.copyWith(
        headers: {...options.headers, 'Authorization': 'Bearer $newToken'},
        extra: {...options.extra, retriedKey: true},
      );
      final retried = await dio.fetch(retry);
      handler.resolve(retried);
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  static String? _bearer(Object? header) {
    final value = header?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    return value.toLowerCase().startsWith('bearer ')
        ? value.substring(7).trim()
        : value;
  }
}
