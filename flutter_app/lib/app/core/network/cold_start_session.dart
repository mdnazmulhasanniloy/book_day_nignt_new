import 'package:dio/dio.dart';

import 'auth_refresh_coordinator.dart';

/// What the splash screen should do after the cold-start `/auth/check`.
enum ColdStartOutcome {
  /// Signed in (valid, refreshed, or unverifiable because of a transient
  /// failure): go to the role dashboard. Tokens are left untouched.
  proceedLoggedIn,

  /// No session (guest, or the server answered `success: false`): onboarding.
  showOnboarding,

  /// The coordinator already ended the session and the expired handler already
  /// navigated to login. Splash must not navigate again.
  alreadyAtLogin,
}

/// Decides the cold-start destination. Pure Dart so it can be tested with the
/// real interceptor and coordinator.
///
/// [runCheck] performs `POST /auth/check` through the app Dio (so the
/// interceptor refreshes an expired access token and retries). It may throw.
///
/// Splash never clears tokens because of a 401 or 403 that survived the
/// interceptor: that means a transient refresh failure (offline, timeout, 5xx)
/// or a permission error. Only the coordinator ends a session, by clearing the
/// store and calling the expired handler; that is detected here by the access
/// token having disappeared.
Future<ColdStartOutcome> resolveColdStartSession({
  required AuthTokenStore store,
  required Future<Response> Function(String accessToken) runCheck,
}) async {
  final token = store.accessToken ?? '';
  if (token.isEmpty) return ColdStartOutcome.showOnboarding;

  Response? response;
  try {
    response = await runCheck(token);
  } catch (_) {
    // Network error, 5xx, 401/403 surfaced as exceptions: keep the session.
  }

  if ((store.accessToken ?? '').isEmpty) {
    return ColdStartOutcome.alreadyAtLogin;
  }

  final status = response?.statusCode ?? 0;
  final body = response?.data;
  if (status >= 200 &&
      status < 300 &&
      body is Map &&
      body['success'] == false) {
    await store.clearSession();
    return ColdStartOutcome.showOnboarding;
  }
  return ColdStartOutcome.proceedLoggedIn;
}
