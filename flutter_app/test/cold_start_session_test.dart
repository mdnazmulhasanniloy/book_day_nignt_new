import 'package:bookdianight_app/app/core/network/auth_refresh_coordinator.dart';
import 'package:bookdianight_app/app/core/network/auth_refresh_interceptor.dart';
import 'package:bookdianight_app/app/core/network/auth_session.dart';
import 'package:bookdianight_app/app/core/network/cold_start_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_refresh_test.dart' show FakeAdapter, FakeStore, json;

/// Real interceptor + real coordinator + real bareDioRefreshCall over a fake
/// HTTP adapter. Only the server and the storage are fake.
class ColdStart {
  ColdStart({
    String? access = 'old-access',
    String? refresh = 'old-refresh',
    this.accessValid = false,
    this.refreshBehavior = 'ok',
    this.checkForbidden = false,
    this.throwOnError = true,
  }) : store = FakeStore(accessToken: access, refreshToken: refresh, role: 'USER') {
    api = FakeAdapter((o) async {
      if (o.path == '/auth/refresh') {
        switch (refreshBehavior) {
          case 'ok':
            if ((o.data as Map)['refreshToken'] == 'old-refresh') {
              return json(200, {
                'success': true,
                'data': {'token': 'new-access', 'refreshToken': 'new-refresh'},
              });
            }
            return json(401, {'success': false});
          case '400':
            return json(400, {'success': false});
          case '401':
            return json(401, {'success': false});
          case '403':
            return json(403, {'success': false});
          case '5xx':
            return json(503, {'success': false});
          case 'timeout':
            throw DioException(
              requestOptions: o,
              type: DioExceptionType.receiveTimeout,
            );
          default:
            throw DioException(
              requestOptions: o,
              type: DioExceptionType.connectionError,
            );
        }
      }
      if (o.path == '/auth/check') {
        final auth = o.headers['Authorization'];
        final good = accessValid ? 'Bearer old-access' : 'Bearer new-access';
        if (auth == good) return json(200, {'success': true});
        return json(checkForbidden ? 403 : 401, {'success': false});
      }
      return json(404, {'success': false});
    });
    final refreshDio = Dio(
      BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true),
    )..httpClientAdapter = api;
    coordinator = AuthRefreshCoordinator(
      store: store,
      refreshCall: bareDioRefreshCall(baseUrl: 'https://api.test', dio: refreshDio),
      onSessionExpired: () => expired++,
    );
    dio = Dio(BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true))
      ..httpClientAdapter = api;
    dio.interceptors.add(AuthRefreshInterceptor(dio: dio, coordinator: coordinator));
  }

  final FakeStore store;
  final bool accessValid;
  final String refreshBehavior;
  final bool checkForbidden;
  final bool throwOnError;
  late final FakeAdapter api;
  late final AuthRefreshCoordinator coordinator;
  late final Dio dio;
  int expired = 0;
  int checkRuns = 0;

  /// Mimics BaseClient: non-2xx statuses surface as exceptions.
  Future<Response> _check(String token) async {
    checkRuns++;
    final res = await dio.post(
      '/auth/check',
      data: {'deviceIdentifier': 'dev'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (throwOnError && (res.statusCode ?? 0) >= 400) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return res;
  }

  Future<ColdStartOutcome> run() =>
      resolveColdStartSession(store: store, runCheck: _check);

  int get refreshCalls => api.count('/auth/refresh');
}

void main() {
  test('valid access token: proceeds, no refresh, nothing cleared', () async {
    final c = ColdStart(accessValid: true);
    expect(await c.run(), ColdStartOutcome.proceedLoggedIn);
    expect(c.refreshCalls, 0);
    expect(c.expired, 0);
    expect(c.store.accessToken, 'old-access');
    expect(c.store.refreshToken, 'old-refresh');
    expect(c.store.role, 'USER');
  });

  test('expired access + refresh ok: retried check, new tokens stored', () async {
    final c = ColdStart();
    expect(await c.run(), ColdStartOutcome.proceedLoggedIn);
    expect(c.refreshCalls, 1);
    expect(c.api.count('/auth/check'), 2);
    expect(c.expired, 0);
    expect(c.store.accessToken, 'new-access');
    expect(c.store.refreshToken, 'new-refresh');
    expect(c.store.role, 'USER');
  });

  for (final behavior in ['net', 'timeout', '5xx']) {
    test('refresh $behavior: session kept, still proceeds logged in', () async {
      final c = ColdStart(refreshBehavior: behavior);
      expect(await c.run(), ColdStartOutcome.proceedLoggedIn);
      expect(c.refreshCalls, 1);
      expect(c.expired, 0);
      expect(c.store.clears, 0);
      expect(c.store.accessToken, 'old-access');
      expect(c.store.refreshToken, 'old-refresh');
      expect(c.store.role, 'USER');
    });
  }

  for (final behavior in ['401', '400', '403']) {
    test('refresh rejected ($behavior): one expiry, splash does not navigate', () async {
      final c = ColdStart(refreshBehavior: behavior);
      expect(await c.run(), ColdStartOutcome.alreadyAtLogin);
      expect(c.refreshCalls, 1);
      expect(c.expired, 1);
      expect(c.store.accessToken, isNull);
      expect(c.store.refreshToken, isNull);
      expect(c.store.role, isNull);
    });
  }

  test('legacy session without refresh token: one expiry, no refresh call', () async {
    final c = ColdStart(refresh: null);
    expect(await c.run(), ColdStartOutcome.alreadyAtLogin);
    expect(c.refreshCalls, 0);
    expect(c.expired, 1);
    expect(c.store.accessToken, isNull);
    expect(c.store.role, isNull);
  });

  test('403 on /auth/check never clears anything', () async {
    final c = ColdStart(checkForbidden: true);
    expect(await c.run(), ColdStartOutcome.proceedLoggedIn);
    expect(c.refreshCalls, 0);
    expect(c.expired, 0);
    expect(c.store.clears, 0);
    expect(c.store.accessToken, 'old-access');
    expect(c.store.refreshToken, 'old-refresh');
    expect(c.store.role, 'USER');
  });

  test('403 returned as a plain response (not thrown) is not treated as failure of the session', () async {
    final c = ColdStart(checkForbidden: true, throwOnError: false);
    expect(await c.run(), ColdStartOutcome.proceedLoggedIn);
    expect(c.store.clears, 0);
    expect(c.store.accessToken, 'old-access');
  });

  test('regression: a surviving 401 (transient refresh failure) no longer clears tokens', () async {
    final c = ColdStart(refreshBehavior: '5xx', throwOnError: false);
    expect(await c.run(), ColdStartOutcome.proceedLoggedIn);
    expect(c.store.clears, 0);
    expect(c.store.accessToken, 'old-access');
    expect(c.store.refreshToken, 'old-refresh');
    expect(c.store.role, 'USER');
  });

  test('guest: onboarding, no request at all', () async {
    final c = ColdStart(access: null, refresh: null);
    c.store.role = null;
    expect(await c.run(), ColdStartOutcome.showOnboarding);
    expect(c.checkRuns, 0);
    expect(c.api.requests, isEmpty);
    expect(c.expired, 0);
  });

  test('2xx with success:false still clears and shows onboarding (unchanged behaviour)', () async {
    final c = ColdStart();
    final outcome = await resolveColdStartSession(
      store: c.store,
      runCheck: (_) async => Response(
        requestOptions: RequestOptions(path: '/auth/check'),
        statusCode: 200,
        data: {'success': false},
      ),
    );
    expect(outcome, ColdStartOutcome.showOnboarding);
    expect(c.store.accessToken, isNull);
    expect(c.expired, 0);
  });

  test('decision runs the check once and never loops', () async {
    final c = ColdStart(refreshBehavior: '401');
    await c.run();
    expect(c.checkRuns, 1);
    expect(c.api.count('/auth/check'), 1);
    expect(c.refreshCalls, 1);
  });
}
