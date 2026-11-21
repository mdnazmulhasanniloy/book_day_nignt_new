import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';
import '../../../../core/explore/model/explore_api_model.dart';

class WishlistRepository {
  WishlistRepository({BaseClient? client}) : _client = client ?? BaseClient();

  final BaseClient _client;

  Map<String, dynamic> _authHeaders() {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<ExploreResponseModel> getWishlist({
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.wishlist,
      params: {'page': page, 'limit': limit},
      headers: _authHeaders(),
    );
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid wishlist response');
    }
    return ExploreResponseModel.fromJson(Map<String, dynamic>.from(body));
  }

  Future<void> addToWishlist({
    required String id,
    required String type,
  }) async {
    final response = await _client.post(
      endpoint: EndPoint.wishlist,
      body: {
        'type': type.trim().toUpperCase(),
        'targetId': id,
      },
      headers: _authHeaders(),
    );
    final body = response.data;
    if (body is Map && body['success'] == false) {
      throw Exception(body['message']?.toString() ?? 'Failed to add wishlist');
    }
  }

  Future<void> removeFromWishlist({
    required String id,
    required String type,
  }) async {
    final response = await _client.delete(
      endpoint: EndPoint.removeWishlist(type, id),
      headers: _authHeaders(),
    );
    final body = response.data;
    if (body is Map && body['success'] == false) {
      throw Exception(
        body['message']?.toString() ?? 'Failed to remove wishlist',
      );
    }
  }
}
