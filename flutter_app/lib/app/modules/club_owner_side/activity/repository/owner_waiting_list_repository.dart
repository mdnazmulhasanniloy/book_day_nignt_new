import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';
import '../model/owner_waiting_list_model.dart';

class OwnerWaitingListRepository {
  OwnerWaitingListRepository({BaseClient? client})
    : _client = client ?? BaseClient();

  final BaseClient _client;

  Future<OwnerWaitingListPage> list({
    required String clubId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.waitingListClub(clubId),
      params: {'page': page, 'limit': limit},
      headers: _headers,
    );
    final body = response.data;
    return OwnerWaitingListPage.fromJson(
      body is Map ? Map<String, dynamic>.from(body) : const <String, dynamic>{},
    );
  }

  Future<OwnerWaitingListEntry> notify(String entryId) async {
    final response = await _client.post(
      endpoint: EndPoint.waitingListNotify(entryId),
      body: const <String, dynamic>{},
      headers: _headers,
    );
    final body = response.data;
    final map = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    if (map['success'] == false) {
      throw StateError(
        map['message']?.toString() ?? 'Could not notify this guest',
      );
    }
    final data = map['data'];
    if (data is Map) {
      return OwnerWaitingListEntry.fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('Could not notify this guest');
  }

  Future<void> remove(String entryId) async {
    final response = await _client.delete(
      endpoint: EndPoint.waitingListEntry(entryId),
      headers: _headers,
    );
    final body = response.data;
    if (body is Map && body['success'] == false) {
      throw StateError(
        body['message']?.toString() ?? 'Could not remove this guest',
      );
    }
  }

  Map<String, dynamic> get _headers {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
