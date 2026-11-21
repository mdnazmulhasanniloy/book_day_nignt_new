import '../../../core/local_storage/local_storage.dart';
import '../../../core/network/base_client.dart';
import '../../../core/network/end_point.dart';
import '../../../core/resources/app_const/app_const.dart';
import '../model/notification_model.dart';

class NotificationPage {
  const NotificationPage({required this.items, required this.totalPages});

  final List<NotificationModel> items;
  final int totalPages;
}

class NotificationRepository {
  NotificationRepository({BaseClient? client})
    : _client = client ?? BaseClient();

  final BaseClient _client;

  Map<String, dynamic> _authHeaders() {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<NotificationPage> fetchNotifications({
    required int page,
    int limit = 10,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.notifications,
      params: {'page': page, 'limit': limit},
      headers: _authHeaders(),
    );
    final body = response.data;
    final map = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    final data = map['data'];
    final meta = map['meta'];
    final totalPages = meta is Map
        ? int.tryParse(meta['totalPages']?.toString() ?? '') ?? 0
        : 0;
    final items = data is List
        ? data
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.isNotEmpty)
              .toList()
        : <NotificationModel>[];
    return NotificationPage(items: items, totalPages: totalPages);
  }

  Future<int> fetchUnreadCount() async {
    final response = await _client.get(
      endpoint: '/notifications/unread-count',
      headers: _authHeaders(),
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map || int.tryParse('${data['unreadCount']}') == null) {
      throw const FormatException('Invalid unread count');
    }
    return int.parse('${data['unreadCount']}');
  }

  Future<void> markRead(String id) async {
    await _client.patch(
      endpoint: '/notifications/${Uri.encodeComponent(id)}/read',
      headers: _authHeaders(),
    );
  }

  Future<void> markAllRead() async {
    await _client.patch(
      endpoint: EndPoint.notificationsReadAll,
      headers: _authHeaders(),
    );
  }
}
