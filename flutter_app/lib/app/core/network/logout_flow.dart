import 'auth_refresh_coordinator.dart';

typedef LogoutPost = Future<void> Function(
  Map<String, dynamic> body,
  Map<String, dynamic> headers,
);

/// `POST /auth/logout` plus local cleanup.
///
/// Backend contract (`logoutSchema`, strict): `{deviceIdentifier: string,
/// refreshToken?: string}`, Bearer access token required. When `refreshToken`
/// is present the server revokes that refresh session. It is sent only when a
/// non-empty one is stored (empty would fail validation).
///
/// Known limitation: if the access token is already expired the request gets a
/// 401 and the server-side refresh session is not revoked (best effort).
class LogoutFlow {
  LogoutFlow({
    required this.store,
    required this.post,
    required this.deviceIdentifier,
    this.onCleared,
  });

  final AuthTokenStore store;
  final LogoutPost post;
  final String Function() deviceIdentifier;

  /// Runs after local credentials are cleared (deep-link / notification hooks).
  final Future<void> Function()? onCleared;

  bool _inFlight = false;
  bool get inFlight => _inFlight;

  static Map<String, dynamic> buildBody({
    required String deviceIdentifier,
    String? refreshToken,
  }) {
    final refresh = refreshToken?.trim() ?? '';
    return {
      'deviceIdentifier': deviceIdentifier,
      if (refresh.isNotEmpty) 'refreshToken': refresh,
    };
  }

  /// Returns false when a logout is already running (duplicate tap ignored).
  /// Local credentials are always cleared, even when the request fails.
  Future<bool> run() async {
    if (_inFlight) return false;
    _inFlight = true;
    try {
      final access = store.accessToken ?? '';
      final body = buildBody(
        deviceIdentifier: deviceIdentifier(),
        refreshToken: store.refreshToken,
      );
      try {
        await post(body, {
          if (access.isNotEmpty) 'Authorization': 'Bearer $access',
        });
      } catch (_) {
        // Best effort: the user is signed out locally regardless.
      }
    } finally {
      try {
        await store.clearSession();
      } finally {
        try {
          await onCleared?.call();
        } finally {
          _inFlight = false;
        }
      }
    }
    return true;
  }
}
