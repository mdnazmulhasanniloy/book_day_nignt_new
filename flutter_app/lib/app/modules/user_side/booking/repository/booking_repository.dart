import 'dart:typed_data';

import '../../../../core/explore/model/explore_api_model.dart';
import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/api_expection.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';
import '../model/booking_detail_model.dart';

class BookingRepository {
  BookingRepository({BaseClient? client}) : _client = client ?? BaseClient();

  final BaseClient _client;

  Map<String, dynamic> _authHeaders() {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<ExploreResponseModel> fetchBookings({
    required String tab,
    required int page,
    int limit = 10,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.bookings,
      params: {
        'tab': tab,
        'page': page,
        'limit': limit,
      },
      headers: _authHeaders(),
    );
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid bookings response');
    }
    return ExploreResponseModel.fromJson(Map<String, dynamic>.from(body));
  }

  Future<BookingDetailModel> fetchBookingDetail({
    required String id,
    required String type,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.bookingById(id),
      params: {'type': type},
      headers: _authHeaders(),
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map) {
      throw const FormatException('Invalid booking detail response');
    }
    return BookingDetailModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Uint8List> fetchTicket(String id) async {
    final headers = Map<String, dynamic>.from(_authHeaders())
      ..['Accept'] = 'application/pdf, */*';
    try {
      return await _client.getAuthorizedFile(
        endpoint: EndPoint.bookingTicketFile(id),
        headers: headers,
      );
    } catch (_) {
      final response = await _client.get(
        endpoint: EndPoint.bookingTicket(id),
        headers: _authHeaders(),
      );
      final body = response.data;
      final map = body is Map ? Map<String, dynamic>.from(body) : null;
      final data = map?['data'];
      final ticketUrl = data is Map
          ? data['ticketUrl']?.toString().trim()
          : null;
      if (ticketUrl == null || ticketUrl.isEmpty) {
        throw ApiException('Ticket could not be loaded.', response.statusCode);
      }
      return _client.getAuthorizedFile(
        endpoint: _apiPath(ticketUrl),
        headers: headers,
      );
    }
  }

  String _apiPath(String url) {
    final value = url.trim();
    if (value.startsWith('/')) return value;
    final uri = Uri.tryParse(value);
    final base = Uri.tryParse(EndPoint.BASE_URL);
    if (uri == null || base == null || !uri.hasScheme || uri.host != base.host) {
      return value;
    }
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    var path = uri.path;
    if (prefix.isNotEmpty && path.startsWith(prefix)) {
      path = path.substring(prefix.length);
    }
    if (path.isEmpty) path = '/';
    if (!path.startsWith('/')) path = '/$path';
    if (uri.hasQuery) return '$path?${uri.query}';
    return path;
  }
}
