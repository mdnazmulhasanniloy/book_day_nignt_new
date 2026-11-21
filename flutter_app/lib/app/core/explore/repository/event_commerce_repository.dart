import '../../local_storage/local_storage.dart';
import '../../network/base_client.dart';
import '../../network/end_point.dart';
import '../../resources/app_const/app_const.dart';
import '../model/event_commerce_model.dart';

class EventCommerceRepository {
  EventCommerceRepository({BaseClient? client})
    : _client = client ?? BaseClient();

  final BaseClient _client;

  Future<bool> followArtist(String artistId, {required bool follow}) async {
    final endpoint = EndPoint.artistFollow(artistId);
    final response = follow
        ? await _client.post(
            endpoint: endpoint,
            body: const <String, dynamic>{},
            headers: _headers(),
          )
        : await _client.delete(endpoint: endpoint, headers: _headers());
    final data = _dataMap(response.data);
    if (data.containsKey('isFollowing')) return data['isFollowing'] == true;
    return follow;
  }

  Future<List<FollowedArtistModel>> myArtists({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.meArtists,
      params: {'page': page, 'limit': limit},
      headers: _headers(),
    );
    final body = response.data;
    final raw = body is Map ? body['data'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) => FollowedArtistModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> joinGuestList({
    required String eventId,
    required String name,
    required String email,
    required String phone,
    required int menCount,
    required int womenCount,
    int otherCount = 0,
    required bool acceptedTerms,
    String? arrivalTime,
  }) async {
    await _client.post(
      endpoint: EndPoint.eventGuestListJoin(eventId),
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'menCount': menCount,
        'womenCount': womenCount,
        'otherCount': otherCount,
        'acceptedTerms': acceptedTerms,
        if (arrivalTime != null && arrivalTime.trim().isNotEmpty)
          'arrivalTime': arrivalTime.trim(),
      },
      headers: _headers(),
    );
  }

  Future<void> requestQuote({
    required String eventId,
    required String moduleId,
    required String name,
    required String email,
    required String phone,
    required int guestCount,
    required String message,
    DateTime? date,
  }) async {
    await _client.post(
      endpoint: EndPoint.quotes,
      body: quoteBody(
        eventId: eventId,
        moduleId: moduleId,
        name: name,
        email: email,
        phone: phone,
        guestCount: guestCount,
        message: message,
        date: date,
      ),
      headers: _headers(),
    );
  }

  static Map<String, dynamic> quoteBody({
    required String eventId,
    required String moduleId,
    required String name,
    required String email,
    required String phone,
    required int guestCount,
    required String message,
    DateTime? date,
  }) {
    final note = message.trim();
    if (note.isEmpty) {
      throw ArgumentError('message is required');
    }
    return {
      'eventId': eventId.trim(),
      'moduleId': moduleId.trim(),
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'guestCount': guestCount,
      'message': note,
      if (date != null) 'date': date.toUtc().toIso8601String(),
    };
  }

  Future<List<EventQuoteModel>> ownerQuotes({
    String? eventId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.quotes,
      params: {
        'page': page,
        'limit': limit,
        if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
      },
      headers: _headers(),
    );
    final body = response.data;
    return EventQuoteModel.listFrom(body is Map ? body['data'] : null);
  }

  Future<void> updateQuoteStatus(String id, String status) async {
    await _client.put(
      endpoint: EndPoint.quoteById(id),
      body: {'status': status.trim().toUpperCase()},
      headers: _headers(),
    );
  }

  Future<void> contactHost({
    required String hostId,
    required String name,
    required String email,
    required String phone,
    required String message,
    String? eventId,
  }) async {
    await _client.post(
      endpoint: EndPoint.hostContact(hostId),
      body: hostContactBody(
        name: name,
        email: email,
        phone: phone,
        message: message,
        eventId: eventId,
      ),
      headers: _headers(),
    );
  }

  static Map<String, dynamic> hostContactBody({
    required String name,
    required String email,
    required String phone,
    required String message,
    String? eventId,
  }) {
    final note = message.trim();
    if (note.isEmpty) {
      throw ArgumentError('message is required');
    }
    return {
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'message': note,
      if (eventId != null && eventId.trim().isNotEmpty)
        'eventId': eventId.trim(),
    };
  }

  Future<List<EventVipModuleModel>> ownerModules(String eventId) async {
    final response = await _client.get(
      endpoint: EndPoint.eventModules(eventId),
      headers: _headers(),
    );
    final body = response.data;
    final raw = body is Map ? (body['data'] ?? body['modules']) : body;
    return EventVipModuleModel.listFrom(raw);
  }

  Future<EventVipModuleModel> saveModule({
    required String eventId,
    required EventVipModuleModel module,
  }) async {
    final isUpdate = module.id.trim().isNotEmpty;
    final response = isUpdate
        ? await _client.put(
            endpoint: EndPoint.eventModuleById(eventId, module.id),
            body: module.toPayload(),
            headers: _headers(),
          )
        : await _client.post(
            endpoint: EndPoint.eventModules(eventId),
            body: module.toPayload(),
            headers: _headers(),
          );
    return _moduleFrom(response.data, module);
  }

  Future<void> deleteModule({
    required String eventId,
    required String moduleId,
  }) async {
    await _client.delete(
      endpoint: EndPoint.eventModuleById(eventId, moduleId),
      headers: _headers(),
    );
  }

  Future<EventVipModuleModel> duplicateModule({
    required String eventId,
    required String moduleId,
  }) async {
    final response = await _client.post(
      endpoint: EndPoint.eventModuleDuplicate(eventId, moduleId),
      body: const <String, dynamic>{},
      headers: _headers(),
    );
    return _moduleFrom(response.data, const EventVipModuleModel());
  }

  Future<EventGuestListModel?> fetchGuestList(String eventId) async {
    try {
      final response = await _client.get(
        endpoint: EndPoint.eventGuestList(eventId),
        headers: _headers(),
      );
      final body = response.data;
      final raw = body is Map ? body['data'] : null;
      if (raw is Map) {
        return EventGuestListModel.tryFrom(raw);
      }
    } catch (_) {}

    try {
      final response = await _client.get(
        endpoint: EndPoint.exploreById(eventId),
        params: const {'type': 'EVENT'},
        headers: _headers(),
      );
      final body = response.data;
      final raw = body is Map ? body['data'] : null;
      if (raw is Map && raw['guestList'] != null) {
        return EventGuestListModel.tryFrom(raw['guestList']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<EventGuestListEntry>> guestListEntries(String eventId) async {
    final response = await _client.get(
      endpoint: EndPoint.eventGuestListEntries(eventId),
      headers: _headers(),
    );
    final body = response.data;
    final raw = body is Map ? body['data'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) => EventGuestListEntry.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> upsertGuestList({
    required String eventId,
    required EventGuestListModel config,
  }) async {
    await _client.put(
      endpoint: EndPoint.eventGuestList(eventId),
      body: {
        'isEnabled': config.isOpen,
        if (config.remainingMale != null) 'remainingMale': config.remainingMale,
        if (config.remainingFemale != null)
          'remainingFemale': config.remainingFemale,
        if (config.remainingTotal != null)
          'remainingTotal': config.remainingTotal,
        'arrivalTimes': config.arrivalTimes,
        if (config.cutoffAt != null)
          'cutoffAt': config.cutoffAt!.toUtc().toIso8601String(),
        if (config.dressCode.trim().isNotEmpty) 'dressCode': config.dressCode,
        if (config.notes.trim().isNotEmpty) 'notes': config.notes,
        'idRequired': config.idRequired,
        'fallbacks': config.fallbacks
            .map((item) => item.toPayload())
            .toList(),
      },
      headers: _headers(),
    );
  }

  Future<void> updateGuestListEntry({
    required String eventId,
    required String entryId,
    required String status,
  }) async {
    final normalizedStatus = status.trim().toUpperCase() == 'APPROVED'
        ? 'CONFIRMED'
        : status.trim().toUpperCase();
    await _client.put(
      endpoint: EndPoint.eventGuestListEntry(eventId, entryId),
      body: {'status': normalizedStatus},
      headers: _headers(),
    );
  }

  Future<List<EventHostModel>> ownerHosts() async {
    final response = await _client.get(
      endpoint: EndPoint.hosts,
      headers: _headers(),
    );
    final body = response.data;
    return EventHostModel.listFrom(body is Map ? body['data'] : null);
  }

  Future<List<EventHostModel>> eventHosts(String eventId) async {
    try {
      final response = await _client.get(
        endpoint: EndPoint.eventHosts(eventId),
        headers: _headers(),
      );
      final body = response.data;
      if (body is Map) {
        final data = body['data'];
        final listed = EventHostModel.listFrom(data);
        if (listed.isNotEmpty) return listed;
        if (data is Map) {
          final nested = EventHostModel.listFrom(data['hosts'] ?? data['items']);
          if (nested.isNotEmpty) return nested;
          final single = EventHostModel.fromJson(Map<String, dynamic>.from(data));
          if (single.id.isNotEmpty) return [single];
        }
      }
    } catch (_) {
      // Endpoint /event/:id/hosts may not be available; fall back to explore below.
    }

    try {
      final response = await _client.get(
        endpoint: EndPoint.exploreById(eventId),
        params: const {'type': 'EVENT'},
        headers: _headers(),
      );
      final body = response.data;
      final raw = body is Map ? body['data'] : null;
      if (raw is Map && raw['hosts'] != null) {
        return EventHostModel.listFrom(raw['hosts']);
      }
    } catch (_) {}

    return const [];
  }

  Future<List<EventHostInquiryModel>> eventHostInquiries(String eventId) async {
    final response = await _client.get(
      endpoint: EndPoint.eventHostInquiries(eventId),
      headers: _headers(),
    );
    final body = response.data;
    final raw = body is Map ? (body['data'] ?? body['inquiries']) : body;
    return EventHostInquiryModel.listFrom(raw);
  }

  Future<void> unassignHostFromEvent({
    required String eventId,
    required String hostId,
  }) async {
    await _client.delete(
      endpoint: '${EndPoint.eventHosts(eventId)}/${hostId.trim()}',
      headers: _headers(),
    );
  }

  Future<EventHostModel> saveHost(EventHostModel host) async {
    final isUpdate = host.id.trim().isNotEmpty;
    final response = isUpdate
        ? await _client.put(
            endpoint: EndPoint.hostById(host.id),
            body: host.toPayload(),
            headers: _headers(),
          )
        : await _client.post(
            endpoint: EndPoint.hosts,
            body: host.toPayload(),
            headers: _headers(),
          );
    final data = _dataMap(response.data);
    if (data.isEmpty) return host;
    return EventHostModel.fromJson(data);
  }

  Future<void> deleteHost(String id) async {
    await _client.delete(endpoint: EndPoint.hostById(id), headers: _headers());
  }

  Future<void> assignHostToEvent({
    required String eventId,
    required String hostId,
  }) async {
    await _client.post(
      endpoint: EndPoint.eventHosts(eventId),
      body: {'hostId': hostId.trim()},
      headers: _headers(),
    );
  }

  Future<void> assignHostToClub({
    required String clubId,
    required String hostId,
  }) async {
    await _client.post(
      endpoint: EndPoint.clubHosts(clubId),
      body: {'hostId': hostId.trim()},
      headers: _headers(),
    );
  }

  Future<void> duplicateEvent(String eventId) async {
    await _client.post(
      endpoint: EndPoint.eventDuplicate(eventId),
      body: const <String, dynamic>{},
      headers: _headers(),
    );
  }

  Future<void> closeEventBookings(String eventId, {required bool closed}) async {
    await _client.put(
      endpoint: EndPoint.eventBookingsClose(eventId),
      body: {'closed': closed},
      headers: _headers(),
    );
  }

  Future<String?> exportBookings({
    required String type,
    required DateTime from,
    required DateTime to,
    String? eventId,
    String? clubId,
  }) async {
    var start = from.toUtc();
    var end = to.toUtc();
    if (end.isBefore(start)) {
      final swap = start;
      start = end;
      end = swap;
    }
    final kind = type.trim().toUpperCase();
    final scopedEvent = eventId?.trim() ?? '';
    final scopedClub = clubId?.trim() ?? '';
    final response = await _client.get(
      endpoint: EndPoint.ownerBookingsExport,
      params: {
        'type': kind,
        'from': _exportDate(start),
        'to': _exportDate(end),
        if (kind == 'EVENT' && scopedEvent.isNotEmpty) 'eventId': scopedEvent,
        if (kind == 'CLUB' && scopedClub.isNotEmpty) 'clubId': scopedClub,
      },
      headers: _headers(),
    );
    return exportUrlFrom(response.data);
  }

  static String? exportUrlFrom(dynamic data) {
    if (data is String && data.trim().isNotEmpty) return data.trim();
    if (data is! Map) return null;
    final inner = data['data'];
    if (inner is String && inner.trim().isNotEmpty) return inner.trim();
    final maps = <Map>[
      if (inner is Map) inner,
      data,
    ];
    for (final map in maps) {
      for (final key in const [
        'downloadUrl',
        'url',
        'csv',
        'csvUrl',
        'fileUrl',
      ]) {
        final url = map[key]?.toString().trim();
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  EventVipModuleModel _moduleFrom(
    dynamic body,
    EventVipModuleModel fallback,
  ) {
    final data = _dataMap(body);
    if (data.isEmpty) return fallback;
    return EventVipModuleModel.fromJson(data);
  }

  Map<String, dynamic> _dataMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }

  String _exportDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Map<String, dynamic> _headers({String? idempotencyKey}) {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'Idempotency-Key': idempotencyKey,
    };
  }
}
