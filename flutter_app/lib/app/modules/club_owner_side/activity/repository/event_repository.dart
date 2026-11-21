import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';
import '../model/event_api_model.dart';

class EventRepository {
  EventRepository({BaseClient? client}) : _client = client ?? BaseClient();

  final BaseClient _client;

  Future<EventMutationResponseModel> createEvent(
    EventUpsertRequestModel request,
  ) async {
    final response = await _client.post(
      endpoint: EndPoint.events,
      body: request.toJson(isUpdate: false),
      headers: _authorizedHeaders,
    );
    return EventMutationResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<EventListResponseModel> getOwnEvents({
    int page = 1,
    int limit = 10,
    String? eventStatus,
    bool? isActive,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (eventStatus != null && eventStatus.trim().isNotEmpty) {
      params['eventStatus'] = eventStatus.trim().toUpperCase();
    }
    if (isActive != null) params['isActive'] = isActive;

    final response = await _client.get(
      endpoint: EndPoint.events,
      params: params,
      headers: _authorizedHeaders,
    );
    return EventListResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<EventDetailResponseModel> getEventDetail(String id) async {
    final response = await _client.get(
      endpoint: EndPoint.eventById(id),
      headers: _authorizedHeaders,
    );
    final parsed = EventDetailResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
    final data = parsed.data;
    if (data == null ||
        (data.ticketTiers.isNotEmpty && data.lineup.isNotEmpty)) {
      return parsed;
    }
    try {
      final explore = await _client.get(
        endpoint: EndPoint.exploreById(id),
        params: const {'type': 'EVENT'},
        headers: _authorizedHeaders,
      );
      final body = Map<String, dynamic>.from(explore.data as Map);
      final inner = body['data'];
      if (inner is! Map) return parsed;
      return EventDetailResponseModel(
        success: parsed.success,
        message: parsed.message,
        data: data.withOffersFrom(
          EventDataModel.fromJson(Map<String, dynamic>.from(inner)),
        ),
      );
    } catch (_) {
      return parsed;
    }
  }

  Future<EventMutationResponseModel> updateEvent({
    required String id,
    required EventUpsertRequestModel request,
  }) async {
    final response = await _client.put(
      endpoint: EndPoint.eventById(id),
      body: request.toJson(isUpdate: true),
      headers: _authorizedHeaders,
    );
    return EventMutationResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Map<String, dynamic> get _authorizedHeaders {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
