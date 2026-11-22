import 'dart:convert';

import 'package:bookdianight_app/app/core/network/auth_refresh_coordinator.dart';
import 'package:bookdianight_app/app/core/network/auth_refresh_interceptor.dart';
import 'package:bookdianight_app/app/core/network/auth_session.dart';
import 'package:bookdianight_app/app/core/network/logout_flow.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_refresh_test.dart' show FakeAdapter, FakeStore, json;

/// Fake backend: /auth/logout follows the strict logoutSchema and revokes the
/// supplied refresh token; /auth/refresh rejects revoked tokens.
class LogoutHarness {
  LogoutHarness({
    String? access = 'access-1',
    String? refresh = 'refresh-1',
    this.logoutStatus = 200,
    this.logoutThrows = false,
    this.accessValid = true,
    this.logoutDelay = Duration.zero,
  }) : store = FakeStore(accessToken: access, refreshToken: refresh, role: 'USER') {
    api = FakeAdapter((o) async {
      if (o.path == '/auth/logout') {
        if (logoutDelay != Duration.zero) await Future<void>.delayed(logoutDelay);
        if (logoutThrows) {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        if (!accessValid) return json(401, {'success': false});
        final body = o.data as Map;
        const allowed = {'deviceIdentifier', 'refreshToken'};
        final deviceOk = body['deviceIdentifier'] is String &&
            (body['deviceIdentifier'] as String).isNotEmpty;
        final extraKeys = body.keys.any((k) => !allowed.contains(k));
        final badRefresh =
            body.containsKey('refreshToken') &&
            !(body['refreshToken'] is String &&
                (body['refreshToken'] as String).isNotEmpty);
        if (!deviceOk || extraKeys || badRefresh) {
          return json(422, {'success': false});
        }
        if (body['refreshToken'] != null) revoked.add(body['refreshToken'] as String);
        return json(logoutStatus, {'success': logoutStatus == 200});
      }
      if (o.path == '/auth/refresh') {
        final sent = (o.data as Map)['refreshToken'];
        if (revoked.contains(sent)) return json(401, {'success': false});
        return json(200, {
          'success': true,
          'data': {'token': 'a-new', 'refreshToken': 'r-new'},
        });
      }
      return json(404, {'success': false});
    });
    coordinator = AuthRefreshCoordinator(
      store: store,
      refreshCall: bareDioRefreshCall(
        baseUrl: 'https://api.test',
        dio: Dio(BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true))
          ..httpClientAdapter = api,
      ),
      onSessionExpired: () => expired++,
    );
    dio = Dio(BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true))
      ..httpClientAdapter = api;
    dio.interceptors.add(AuthRefreshInterceptor(dio: dio, coordinator: coordinator));
    flow = LogoutFlow(
      store: store,
      deviceIdentifier: () => 'device-1',
      post: (body, headers) async {
        final res = await dio.post(
          '/auth/logout',
          data: body,
          options: Options(headers: headers),
        );
        if ((res.statusCode ?? 0) >= 400) throw Exception('HTTP ${res.statusCode}');
      },
      onCleared: () async => hooks++,
    );
  }

  final FakeStore store;
  final int logoutStatus;
  final bool logoutThrows;
  final bool accessValid;
  final Duration logoutDelay;
  final Set<String> revoked = {};
  late final FakeAdapter api;
  late final AuthRefreshCoordinator coordinator;
  late final Dio dio;
  late final LogoutFlow flow;
  int expired = 0;
  int hooks = 0;

  RequestOptions get logoutRequest =>
      api.requests.firstWhere((r) => r.path == '/auth/logout');

  void expectCleared() {
    expect(store.accessToken, isNull);
    expect(store.refreshToken, isNull);
    expect(store.role, isNull);
    expect(hooks, 1);
  }
}

void main() {
  test('success: body is {deviceIdentifier, refreshToken}, Bearer sent, creds cleared', () async {
    final h = LogoutHarness();
    expect(await h.flow.run(), isTrue);
    expect(h.api.count('/auth/logout'), 1);
    expect(h.logoutRequest.data, {
      'deviceIdentifier': 'device-1',
      'refreshToken': 'refresh-1',
    });
    expect(h.logoutRequest.headers['Authorization'], 'Bearer access-1');
    h.expectCleared();
  });

  test('body keys match the backend strict schema (only deviceIdentifier, refreshToken)', () async {
    final h = LogoutHarness();
    await h.flow.run();
    final keys = (h.logoutRequest.data as Map).keys.toSet();
    expect(keys, {'deviceIdentifier', 'refreshToken'});
    // The fake server answers 422 for any other key; 200 proves acceptance.
    expect(h.revoked, {'refresh-1'});
    expect(jsonDecode(jsonEncode(h.logoutRequest.data)), isA<Map>());
  });

  test('no stored refresh token: body is exactly {deviceIdentifier}', () async {
    final h = LogoutHarness(refresh: null);
    await h.flow.run();
    expect(h.logoutRequest.data, {'deviceIdentifier': 'device-1'});
    expect(h.revoked, isEmpty);
    h.expectCleared();
  });

  test('empty or blank refresh token is never sent', () {
    expect(
      LogoutFlow.buildBody(deviceIdentifier: 'd', refreshToken: ''),
      {'deviceIdentifier': 'd'},
    );
    expect(
      LogoutFlow.buildBody(deviceIdentifier: 'd', refreshToken: '  '),
      {'deviceIdentifier': 'd'},
    );
    expect(
      LogoutFlow.buildBody(deviceIdentifier: 'd', refreshToken: null),
      {'deviceIdentifier': 'd'},
    );
  });

  test('server 500: local credentials still cleared', () async {
    final h = LogoutHarness(logoutStatus: 500);
    await h.flow.run();
    h.expectCleared();
  });

  test('network error: local credentials still cleared', () async {
    final h = LogoutHarness(logoutThrows: true);
    await h.flow.run();
    h.expectCleared();
  });

  test('post throwing synchronously-style exception still clears', () async {
    final h = LogoutHarness();
    final flow = LogoutFlow(
      store: h.store,
      deviceIdentifier: () => 'device-1',
      post: (_, _) async => throw StateError('boom'),
      onCleared: () async => h.hooks++,
    );
    await flow.run();
    h.expectCleared();
  });

  test('duplicate taps send exactly one request', () async {
    final h = LogoutHarness(logoutDelay: const Duration(milliseconds: 40));
    final results = await Future.wait([h.flow.run(), h.flow.run(), h.flow.run()]);
    expect(results.where((r) => r).length, 1);
    expect(h.api.count('/auth/logout'), 1);
    expect(h.hooks, 1);
    expect(h.flow.inFlight, isFalse);
  });

  test('401 on logout (expired access): no refresh, no expired handler, cleared locally', () async {
    final h = LogoutHarness(accessValid: false);
    await h.flow.run();
    expect(h.api.count('/auth/refresh'), 0);
    expect(h.expired, 0);
    expect(h.api.count('/auth/logout'), 1);
    // Documented limitation: the server did not revoke the refresh session.
    expect(h.revoked, isEmpty);
    h.expectCleared();
  });

  test('a revoked refresh token cannot be refreshed afterwards', () async {
    final h = LogoutHarness();
    final refreshCall = bareDioRefreshCall(
      baseUrl: 'https://api.test',
      dio: Dio(BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true))
        ..httpClientAdapter = h.api,
    );
    expect((await refreshCall('refresh-1')).status, RefreshStatus.success);
    await h.flow.run();
    expect((await refreshCall('refresh-1')).status, RefreshStatus.rejected);
  });

  test('logout can run again after finishing (new session)', () async {
    final h = LogoutHarness();
    await h.flow.run();
    await h.store.saveSession(accessToken: 'access-2', refreshToken: 'refresh-2');
    await h.flow.run();
    expect(h.api.count('/auth/logout'), 2);
    expect(h.revoked, {'refresh-1', 'refresh-2'});
  });
}
