import 'dart:async';

/// Where the coordinator reads and writes the session tokens.
/// The app implementation wraps `LocalStorage`; tests use an in-memory fake.
abstract class AuthTokenStore {
  String? get accessToken;
  String? get refreshToken;
  /// Writes the access and refresh token together (one atomic step for the
  /// caller). A null or empty [refreshToken] removes any stored refresh token,
  /// so a stale, already consumed one is never kept next to a new access token.
  Future<void> saveSession({required String accessToken, String? refreshToken});

  /// Clears access token, refresh token and role.
  Future<void> clearSession();
}

enum RefreshStatus {
  /// New tokens were issued.
  success,

  /// The server refused the refresh token (revoked, expired, used twice).
  rejected,

  /// Network error, timeout or 5xx. The session may still be valid.
  transientFailure,
}

class RefreshResult {
  const RefreshResult.success({required this.accessToken, this.refreshToken})
      : status = RefreshStatus.success;
  const RefreshResult.rejected()
      : status = RefreshStatus.rejected,
        accessToken = null,
        refreshToken = null;
  const RefreshResult.transientFailure()
      : status = RefreshStatus.transientFailure,
        accessToken = null,
        refreshToken = null;

  final RefreshStatus status;
  final String? accessToken;
  final String? refreshToken;
}

/// Persists the tokens of a login response (`data.token` or `data.accessToken`
/// plus `data.refreshToken`) through [store]. Used by every flow that signs the
/// user in. Returns the access token, or null when the response has none.
Future<String?> persistLoginSession(
  AuthTokenStore store,
  Map<String, dynamic>? data,
) async {
  if (data == null) return null;
  String read(String key) => data[key]?.toString().trim() ?? '';
  var access = read('token');
  if (access.isEmpty) access = read('accessToken');
  if (access.isEmpty) return null;
  await store.saveSession(
    accessToken: access,
    refreshToken: read('refreshToken'),
  );
  return access;
}

typedef RefreshCall = Future<RefreshResult> Function(String refreshToken);

/// Single-flight token refresh. Refresh tokens are single use (the backend
/// rotates them), so parallel 401s must share one refresh call.
///
/// Pure Dart: no GetX, no Dio, so it can be unit tested without a device.
class AuthRefreshCoordinator {
  AuthRefreshCoordinator({
    required this.store,
    required this.refreshCall,
    required this.onSessionExpired,
  });

  final AuthTokenStore store;
  final RefreshCall refreshCall;
  final FutureOr<void> Function() onSessionExpired;

  Future<String?>? _inFlight;
  bool _expired = false;

  bool get _hasSession => (store.accessToken ?? '').isNotEmpty;

  /// True when a 401 should be handled: only signed-in users (stored access
  /// token) are ever refreshed or logged out. Guests are left alone.
  bool get hasSession => _hasSession;

  /// Returns a usable access token, or null when the caller should surface the
  /// original 401. [failedAccessToken] is the token the failed request sent.
  Future<String?> refresh({String? failedAccessToken}) {
    if (_hasSession) _expired = false; // a new login re-arms the logout
    final running = _inFlight;
    if (running != null) return running;

    // Another request already refreshed after this one was sent: reuse it.
    final current = store.accessToken ?? '';
    if (current.isNotEmpty &&
        failedAccessToken != null &&
        failedAccessToken.isNotEmpty &&
        current != failedAccessToken) {
      return Future.value(current);
    }

    final future = _doRefresh().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<String?> _doRefresh() async {
    if (!_hasSession) return null;
    final stored = store.refreshToken ?? '';
    if (stored.isEmpty) {
      // Logged in before refresh tokens were stored: nothing to refresh with.
      await _expire();
      return null;
    }
    RefreshResult result;
    try {
      result = await refreshCall(stored);
    } catch (_) {
      result = const RefreshResult.transientFailure();
    }
    switch (result.status) {
      case RefreshStatus.success:
        final access = result.accessToken ?? '';
        if (access.isEmpty) {
          await _expire();
          return null;
        }
        final refreshed = result.refreshToken ?? '';
        if (refreshed.isEmpty) {
          // Never half-update: keep the stored pair untouched.
          return null;
        }
        await store.saveSession(accessToken: access, refreshToken: refreshed);
        return access;
      case RefreshStatus.rejected:
        await _expire();
        return null;
      case RefreshStatus.transientFailure:
        return null; // keep the session; the caller sees the original 401
    }
  }

  Future<void> _expire() async {
    if (_expired) return;
    _expired = true;
    await store.clearSession();
    await onSessionExpired();
  }
}
