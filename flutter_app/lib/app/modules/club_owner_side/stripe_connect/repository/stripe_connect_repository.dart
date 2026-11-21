import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/network/base_client.dart';
import 'package:bookdianight_app/app/core/network/end_point.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:bookdianight_app/app/services/deep_link_service.dart';

class StripeConnectRepository {
  final BaseClient _client = BaseClient();

  Map<String, dynamic> _authHeaders() {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required before payout setup.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> startOnboarding() async {
    final host = DeepLinkService.shareHost;
    final response = await _client.post(
      endpoint: EndPoint.connectOnboarding,
      headers: _authHeaders(),
      body: {
        'returnUrl': '$host/connect/return',
        'refreshUrl': '$host/connect/refresh',
      },
    );
    return _dataMap(response.data);
  }

  Future<Map<String, dynamic>> fetchStatus() async {
    final response = await _client.get(
      endpoint: EndPoint.connectStatus,
      headers: _authHeaders(),
    );
    return _dataMap(response.data);
  }

  Map<String, dynamic> _dataMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }
}
