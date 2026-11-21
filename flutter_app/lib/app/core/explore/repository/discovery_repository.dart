import '../../local_storage/local_storage.dart';
import '../../network/base_client.dart';
import '../../resources/app_const/app_const.dart';

/// Contracts from the deployed Swagger, separate from checkout contracts.
class DiscoveryRepository {
  DiscoveryRepository({BaseClient? client}) : _client = client ?? BaseClient();
  final BaseClient _client;

  Map<String, dynamic> get headers {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    final response = await _client.get(
      endpoint: path,
      params: params,
      headers: headers,
    );
    if (response.data is! Map) throw const FormatException('Invalid response');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      endpoint: path,
      body: body,
      headers: headers,
    );
    if (response.data is! Map) throw const FormatException('Invalid response');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> unfollow(String id) async {
    await _client.delete(
      endpoint: '/clubs/${Uri.encodeComponent(id)}/follow',
      headers: headers,
    );
  }

  static Map<String, dynamic> data(Map<String, dynamic> body) =>
      body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : {};

  static List<Map<String, dynamic>> items(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  static List<String> strings(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) {
          if (item is Map) {
            return (item['name'] ?? item['genre'] ?? '').toString().trim();
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> eventsMatchingGenre(
    List<Map<String, dynamic>> events,
    String genre,
  ) {
    final selected = genre.trim().toLowerCase();
    if (selected.isEmpty) return events;
    return events.where((event) {
      return strings(event['musicGenres']).any(
        (item) => item.toLowerCase() == selected,
      );
    }).toList();
  }
}
