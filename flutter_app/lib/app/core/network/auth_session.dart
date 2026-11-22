import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../modules/authentication/views/login_view.dart';
import '../../services/deep_link_service.dart';
import '../../services/notification_router.dart';
import '../local_storage/local_storage.dart';
import '../resources/app_const/app_const.dart';
import '../utils/custom_snack_bar.dart';
import 'auth_refresh_coordinator.dart';
import 'end_point.dart';

/// [AuthTokenStore] backed by the app's `LocalStorage`.
class LocalAuthTokenStore implements AuthTokenStore {
  const LocalAuthTokenStore();

  @override
  String? get accessToken =>
      LocalStorage.getData(key: AppConst.accessToken)?.toString();

  @override
  String? get refreshToken =>
      LocalStorage.getData(key: AppConst.refreshToken)?.toString();

  @override
  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    final hasRefresh = refreshToken != null && refreshToken.isNotEmpty;
    // Both writes are started before either is awaited, so they land in the
    // same storage flush.
    await Future.wait([
      LocalStorage.saveData(key: AppConst.accessToken, data: accessToken),
      if (hasRefresh)
        LocalStorage.saveData(key: AppConst.refreshToken, data: refreshToken)
      else
        LocalStorage.removeData(key: AppConst.refreshToken),
    ]);
  }

  @override
  Future<void> clearSession() async {
    await LocalStorage.removeData(key: AppConst.accessToken);
    await LocalStorage.removeData(key: AppConst.refreshToken);
    await LocalStorage.removeData(key: AppConst.role);
  }
}

/// Calls `POST /auth/refresh` with a bare Dio (no interceptors, so a failure
/// cannot recurse). Response: `{success, data: {token, refreshToken}}`.
RefreshCall bareDioRefreshCall({required String baseUrl, Dio? dio}) {
  final client = dio ??
      Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );
  return (String refreshToken) async {
    try {
      final response = await client.post(
        EndPoint.REFRESH,
        data: {'refreshToken': refreshToken},
      );
      final status = response.statusCode ?? 0;
      final body = response.data;
      if (status >= 200 && status < 300 && body is Map && body['success'] == true) {
        final data = body['data'];
        if (data is Map) {
          final access = data['token']?.toString().trim() ?? '';
          final refresh = data['refreshToken']?.toString().trim() ?? '';
          if (access.isNotEmpty && refresh.isNotEmpty) {
            return RefreshResult.success(
              accessToken: access,
              refreshToken: refresh,
            );
          }
        }
        // 2xx without both tokens: do not overwrite anything, keep the session.
        return const RefreshResult.transientFailure();
      }
      // Only an answer about the token itself ends the session.
      if (status == 400 || status == 401 || status == 403) {
        return const RefreshResult.rejected();
      }
      return const RefreshResult.transientFailure();
    } on DioException {
      return const RefreshResult.transientFailure();
    }
  };
}

/// Runs once per expired session (the coordinator guards repeats).
Future<void> handleSessionExpired() async {
  DeepLinkService.instance.onLoggedOut();
  NotificationRouter.onLoggedOut();
  if (Get.context == null) {
    debugPrint('Session expired before the app was ready to navigate.');
    return;
  }
  CustomSnackBar.error(message: 'Session expired, please sign in again.');
  Get.offAll(() => const LoginView());
}
