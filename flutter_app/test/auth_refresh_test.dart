import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bookdianight_app/app/core/network/auth_refresh_coordinator.dart';
import 'package:bookdianight_app/app/core/network/auth_refresh_interceptor.dart';
import 'package:bookdianight_app/app/core/network/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStore implements AuthTokenStore {
  FakeStore({this.accessToken, this.refreshToken, this.role});
  @override
  String? accessToken;
  @override
  String? refreshToken;
  String? role;
  int clears = 0;
  int saves = 0;

  @override
  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    saves++;
    this.accessToken = accessToken;
    this.refreshToken =
        (refreshToken == null || refreshToken.isEmpty) ? null : refreshToken;
  }

  @override
  Future<void> clearSession() async {
    clears++;
    accessToken = null;
    refreshToken = null;
    role = null;
  }
}

typedef Responder = FutureOr<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responder);
  final Responder responder;
  final List<RequestOptions> requests = [];

  int count(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

const protectedPath = '/profile';

class Harness {
  Harness({
    String? access = 'old-access',
    String? refresh = 'old-refresh',
    this.refreshBehavior = 'ok',
    this.protectedAlways401 = false,
    this.refreshDelay = const Duration(milliseconds: 30),
  }) : store = FakeStore(accessToken: access, refreshToken: refresh, role: 'USER') {
    api = FakeAdapter((o) async {
      if (o.path == '/auth/refresh') {
        await Future<void>.delayed(refreshDelay);
        final sent = (o.data as Map)['refreshToken'];
        // Refresh tokens are single use: only the current one is accepted.
        if (refreshBehavior == 'ok' && sent == validRefresh) {
          generation++;
          validRefresh = 'refresh-$generation';
          validAccess = 'access-$generation';
          return json(200, {
            'success': true,
            'message': 'ok',
            'data': {'token': validAccess, 'refreshToken': validRefresh},
            'traceId': 't',
          });
        }
        if (refreshBehavior == 'ok') {
          return json(401, {'success': false, 'message': 'TOKEN_BLACKLISTED'});
        }
        if (refreshBehavior == 'missingRefresh') {
          return json(200, {
            'success': true,
            'data': {'token': 'half-access'},
          });
        }
        if (refreshBehavior == '403') return json(403, {'success': false});
        if (refreshBehavior == 'net') {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        if (refreshBehavior == '5xx') return json(503, {'success': false});
        return json(401, {'success': false, 'message': 'TOKEN_BLACKLISTED'});
      }
      if (!protectedAlways401 &&
          o.headers['Authorization'] == 'Bearer $validAccess') {
        return json(200, {'success': true});
      }
      if (o.path == '/auth/login') {
        return json(401, {'success': false, 'message': 'Wrong password'});
      }
      if (o.path == '/forbidden') {
        return json(403, {'success': false});
      }
      return json(401, {'success': false, 'message': 'TOKEN_EXPIRED'});
    });
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true))
      ..httpClientAdapter = api;
    coordinator = AuthRefreshCoordinator(
      store: store,
      refreshCall: bareDioRefreshCall(baseUrl: 'https://api.test', dio: refreshDio),
      onSessionExpired: () => expiredCalls++,
    );
    dio = Dio(BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true))
      ..httpClientAdapter = api;
    dio.interceptors.add(AuthRefreshInterceptor(dio: dio, coordinator: coordinator));
  }

  final FakeStore store;
  final String refreshBehavior;
  final bool protectedAlways401;
  final Duration refreshDelay;
  late final FakeAdapter api;
  late final AuthRefreshCoordinator coordinator;
  late final Dio dio;
  int expiredCalls = 0;
  int generation = 0;
  String validRefresh = 'old-refresh';
  String validAccess = 'access-0-not-issued-yet';

  Future<Response> get(String path, {String? token = 'old-access'}) =>
      dio.get(
        path,
        options: Options(
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        ),
      );
}

void main() {
  test('single 401 refreshes then the retry succeeds', () async {
    final h = Harness();
    final res = await h.get(protectedPath);
    expect(res.statusCode, 200);
    expect(h.api.count('/auth/refresh'), 1);
    expect(h.api.count(protectedPath), 2);
    expect(h.expiredCalls, 0);
  });

  test('new tokens are persisted', () async {
    final h = Harness();
    await h.get(protectedPath);
    expect(h.store.accessToken, 'access-1');
    expect(h.store.refreshToken, 'refresh-1');
    expect(h.store.saves, 1);
  });

  test('refresh request sends the stored refresh token as {refreshToken}', () async {
    final h = Harness();
    await h.get(protectedPath);
    final call = h.api.requests.firstWhere((r) => r.path == '/auth/refresh');
    expect(call.data, {'refreshToken': 'old-refresh'});
    expect(call.headers.containsKey('Authorization'), isFalse);
  });

  test('Authorization header is replaced on the retry', () async {
    final h = Harness();
    await h.get(protectedPath);
    final calls = h.api.requests.where((r) => r.path == protectedPath).toList();
    expect(calls[0].headers['Authorization'], 'Bearer old-access');
    expect(calls[1].headers['Authorization'], 'Bearer access-1');
    expect(calls[1].extra['retried'], true);
  });

  test('5 parallel 401s cause exactly one refresh call', () async {
    final h = Harness();
    final results = await Future.wait(
      List.generate(5, (_) => h.get(protectedPath)),
    );
    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(h.api.count('/auth/refresh'), 1);
    expect(h.expiredCalls, 0);
  });

  test('a late 401 that used the old token reuses the new token', () async {
    final h = Harness();
    await h.get(protectedPath);
    final res = await h.get(protectedPath); // still sends old-access
    expect(res.statusCode, 200);
    expect(h.api.count('/auth/refresh'), 1);
  });

  test('refresh rejected: logs out once, 3 parallel calls, no loop', () async {
    final h = Harness(refreshBehavior: '401');
    final results = await Future.wait(
      List.generate(3, (_) => h.get(protectedPath)),
    );
    expect(results.every((r) => r.statusCode == 401), isTrue);
    expect(h.api.count('/auth/refresh'), 1);
    expect(h.expiredCalls, 1);
    expect(h.store.clears, 1);
    expect(h.store.accessToken, isNull);
    expect(h.store.refreshToken, isNull);
    expect(h.store.role, isNull);
    // Later 401s without a session are guests: nothing more happens.
    await h.get(protectedPath);
    expect(h.expiredCalls, 1);
  });

  test('network/5xx refresh failure keeps the session', () async {
    final h = Harness(refreshBehavior: '5xx');
    final res = await h.get(protectedPath);
    expect(res.statusCode, 401);
    expect(h.expiredCalls, 0);
    expect(h.store.accessToken, 'old-access');
    expect(h.store.refreshToken, 'old-refresh');
  });

  test('a retried request that 401s again does not refresh again', () async {
    final h = Harness(protectedAlways401: true);
    final res = await h.get(protectedPath);
    expect(res.statusCode, 401);
    expect(h.api.count('/auth/refresh'), 1);
    expect(h.api.count(protectedPath), 2);
    expect(h.expiredCalls, 0);
  });

  test('auth-endpoint 401 never refreshes or logs out', () async {
    final h = Harness();
    for (final path in [
      '/auth/login',
      '/auth/signup',
      '/auth/verify',
      '/auth/resend',
      '/auth/social',
      '/auth/google',
      '/recover/verify',
    ]) {
      final res = await h.get(path);
      expect(res.statusCode, 401, reason: path);
    }
    expect(h.api.count('/auth/refresh'), 0);
    expect(h.expiredCalls, 0);
    expect(h.store.accessToken, 'old-access');
  });

  test('403 does not clear the session', () async {
    final h = Harness();
    final res = await h.get('/forbidden');
    expect(res.statusCode, 403);
    expect(h.api.count('/auth/refresh'), 0);
    expect(h.expiredCalls, 0);
    expect(h.store.accessToken, 'old-access');
    expect(h.store.refreshToken, 'old-refresh');
  });

  test('guest 401 does not refresh or navigate', () async {
    final h = Harness(access: null, refresh: null);
    final res = await h.get(protectedPath, token: null);
    expect(res.statusCode, 401);
    final res2 = await h.get(protectedPath, token: 'whatever');
    expect(res2.statusCode, 401);
    expect(h.api.count('/auth/refresh'), 0);
    expect(h.expiredCalls, 0);
    expect(h.store.clears, 0);
  });

  test('no stored refresh token: logs out without calling refresh', () async {
    final h = Harness(refresh: null);
    final res = await h.get(protectedPath);
    expect(res.statusCode, 401);
    expect(h.api.count('/auth/refresh'), 0);
    expect(h.expiredCalls, 1);
    expect(h.store.accessToken, isNull);
  });

  test('request without an Authorization header is not a session problem', () async {
    final h = Harness();
    final res = await h.get(protectedPath, token: null);
    expect(res.statusCode, 401);
    expect(h.api.count('/auth/refresh'), 0);
    expect(h.expiredCalls, 0);
  });

  test('FormData request is not resent but tokens are refreshed', () async {
    final h = Harness();
    final res = await h.dio.post(
      protectedPath,
      data: FormData.fromMap({'a': 'b'}),
      options: Options(headers: {'Authorization': 'Bearer old-access'}),
    );
    expect(res.statusCode, 401);
    expect(h.api.count(protectedPath), 1);
    expect(h.api.count('/auth/refresh'), 1);
    expect(h.store.accessToken, 'access-1');
  });

  test('POST with JSON body is resent with the same body', () async {
    final h = Harness();
    final res = await h.dio.post(
      protectedPath,
      data: {'x': 1},
      options: Options(headers: {'Authorization': 'Bearer old-access'}),
    );
    expect(res.statusCode, 200);
    final calls = h.api.requests.where((r) => r.path == protectedPath).toList();
    expect(calls.length, 2);
    expect(calls[1].data, {'x': 1});
  });

  test('raw byte download (getBytes style) is covered too', () async {
    final h = Harness();
    final res = await h.dio.get<List<int>>(
      protectedPath,
      options: Options(
        headers: {'Authorization': 'Bearer old-access'},
        responseType: ResponseType.bytes,
      ),
    );
    expect(res.statusCode, 200);
    expect(h.api.count('/auth/refresh'), 1);
  });

  test('rotation: second refresh uses the NEW refresh token only', () async {
    final h = Harness();
    await h.get(protectedPath);
    // Expire the new access token on the server side, then 401 again.
    h.validAccess = 'rotated-away';
    final res = await h.get(protectedPath, token: 'access-1');
    expect(res.statusCode, 200);
    final refreshes = h.api.requests.where((r) => r.path == '/auth/refresh').toList();
    expect(refreshes.length, 2);
    expect(refreshes[0].data, {'refreshToken': 'old-refresh'});
    expect(refreshes[1].data, {'refreshToken': 'refresh-1'});
    expect(h.store.refreshToken, 'refresh-2');
    expect(h.expiredCalls, 0);
  });

  test('refresh response missing refreshToken: nothing overwritten, no logout', () async {
    final h = Harness(refreshBehavior: 'missingRefresh');
    final res = await h.get(protectedPath);
    expect(res.statusCode, 401);
    expect(h.store.saves, 0);
    expect(h.store.accessToken, 'old-access');
    expect(h.store.refreshToken, 'old-refresh');
    expect(h.expiredCalls, 0);
  });

  test('network error during refresh: no logout, original 401 returned', () async {
    final h = Harness(refreshBehavior: 'net');
    final res = await h.get(protectedPath);
    expect(res.statusCode, 401);
    expect(h.expiredCalls, 0);
    expect(h.store.clears, 0);
    expect(h.store.accessToken, 'old-access');
    expect(h.store.refreshToken, 'old-refresh');
  });

  test('403 from /auth/refresh counts as invalid token: single logout', () async {
    final h = Harness(refreshBehavior: '403');
    await Future.wait([h.get(protectedPath), h.get(protectedPath)]);
    expect(h.expiredCalls, 1);
    expect(h.store.accessToken, isNull);
  });

  test('getAuthorizedFile style (no redirects, bytes) refreshes and retries once', () async {
    final h = Harness();
    final res = await h.dio.get<List<int>>(
      protectedPath,
      options: Options(
        headers: {'Authorization': 'Bearer old-access'},
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (status) => true,
      ),
    );
    expect(res.statusCode, 200);
    expect(h.api.count(protectedPath), 2);
    expect(h.api.count('/auth/refresh'), 1);
  });

  group('persistLoginSession', () {
    test('email login response stores both tokens', () async {
      final store = FakeStore();
      final access = await persistLoginSession(store, {
        'token': 'a1',
        'refreshToken': 'r1',
        'role': 'USER',
        'isUserVerified': true,
      });
      expect(access, 'a1');
      expect(store.accessToken, 'a1');
      expect(store.refreshToken, 'r1');
      expect(store.saves, 1);
    });

    test('social login response stores both tokens', () async {
      final store = FakeStore();
      await persistLoginSession(store, {
        'accessToken': 'a2',
        'refreshToken': 'r2',
        'role': 'CLUB_OWNER',
      });
      expect(store.accessToken, 'a2');
      expect(store.refreshToken, 'r2');
    });

    test('a new login replaces a stale refresh token', () async {
      final store = FakeStore(accessToken: 'x', refreshToken: 'stale');
      await persistLoginSession(store, {'token': 'a3'});
      expect(store.accessToken, 'a3');
      expect(store.refreshToken, isNull);
    });

    test('response without a token stores nothing', () async {
      final store = FakeStore(accessToken: 'keep', refreshToken: 'keep-r');
      expect(await persistLoginSession(store, {'refreshToken': 'r'}), isNull);
      expect(await persistLoginSession(store, null), isNull);
      expect(store.saves, 0);
      expect(store.accessToken, 'keep');
    });

    test('new session after logout re-arms the single logout', () async {
      final h = Harness(refreshBehavior: '401');
      await h.get(protectedPath);
      expect(h.expiredCalls, 1);
      await persistLoginSession(h.store, {'token': 'login-2', 'refreshToken': 'r-2'});
      await h.get(protectedPath, token: 'login-2');
      expect(h.expiredCalls, 2);
    });
  });
}
