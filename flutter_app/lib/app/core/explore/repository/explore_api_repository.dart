import '../../local_storage/local_storage.dart';
import '../../network/base_client.dart';
import '../../network/end_point.dart';
import '../../resources/app_const/app_const.dart';
import '../model/explore_api_model.dart';

class ExploreApiRepository {
  ExploreApiRepository({BaseClient? client}) : _client = client ?? BaseClient();

  final BaseClient _client;

  Future<ExploreResponseModel> getExplore(ExploreQueryModel query) async {
    final response = await _client.get(
      endpoint: EndPoint.explore,
      params: query.toQueryParameters(),
      headers: const {'Accept': 'application/json'},
    );
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid explore response');
    }
    return ExploreResponseModel.fromJson(Map<String, dynamic>.from(body));
  }

  Future<List<String>> getGenres() async {
    try {
      final response = await _client.get(
        endpoint: EndPoint.exploreGenres,
        headers: const {'Accept': 'application/json'},
      );
      final body = response.data;
      if (body is! Map) return const [];
      final data = body['data'];
      if (data is List) {
        return data
            .map((item) {
              if (item is Map) {
                return (item['name'] ?? item['genre'] ?? '').toString().trim();
              }
              return item.toString().trim();
            })
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<ExploreDetailResponseModel> getExploreDetails({
    required String id,
    required String type,
  }) async {
    final normalizedType = _normalizeExploreType(type);
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    final response = await _client.get(
      endpoint: EndPoint.exploreById(id),
      params: {'type': normalizedType},
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid explore detail response');
    }
    return ExploreDetailResponseModel.fromJson(Map<String, dynamic>.from(body));
  }

  static String _normalizeExploreType(String type) {
    final normalized = type.trim().toUpperCase();
    if (normalized == 'EVENT' || normalized.contains('EVENT')) {
      return 'EVENT';
    }
    return 'CLUB';
  }
}
