import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';
import '../model/promo_api_model.dart';

class PromoRepository {
  PromoRepository({BaseClient? client}) : _client = client ?? BaseClient();

  final BaseClient _client;

  Future<PromoListResponseModel> getOwnPromos({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.promo,
      params: {'page': page, 'limit': limit},
      headers: _authorizedHeaders,
    );
    final body = response.data;
    return PromoListResponseModel.fromJson(
      body is Map ? Map<String, dynamic>.from(body) : const <String, dynamic>{},
    );
  }

  Future<PromoDataModel> createPromo({
    required String code,
    required String discountType,
    required double discountValue,
    required int maxUses,
    String? clubId,
    String? eventId,
    DateTime? expiresAt,
  }) async {
    final response = await _client.post(
      endpoint: EndPoint.promo,
      body: mutationBody(
        code: code,
        discountType: discountType,
        discountValue: discountValue,
        maxUses: maxUses,
        clubId: clubId,
        eventId: eventId,
        expiresAt: expiresAt,
      ),
      headers: _authorizedHeaders,
    );
    return _promoFromResponse(
      response.data,
      fallback: PromoDataModel(
        code: code.trim().toUpperCase(),
        discountType: discountType,
        discountValue: discountValue,
        maxUses: maxUses,
        clubId: clubId ?? '',
        eventId: eventId ?? '',
        expiresAt: expiresAt,
      ),
      failure: 'Could not create promo',
    );
  }

  Future<PromoDataModel> updatePromo({
    required String id,
    required String code,
    required String discountType,
    required double discountValue,
    required int maxUses,
    String? clubId,
    String? eventId,
    DateTime? expiresAt,
    bool isActive = true,
  }) async {
    final response = await _client.put(
      endpoint: EndPoint.promoById(id),
      body: mutationBody(
        code: code,
        discountType: discountType,
        discountValue: discountValue,
        maxUses: maxUses,
        clubId: clubId,
        eventId: eventId,
        expiresAt: expiresAt,
        isActive: isActive,
        isUpdate: true,
      ),
      headers: _authorizedHeaders,
    );
    return _promoFromResponse(
      response.data,
      fallback: PromoDataModel(
        id: id,
        code: code.trim().toUpperCase(),
        discountType: discountType,
        discountValue: discountValue,
        maxUses: maxUses,
        clubId: clubId ?? '',
        eventId: eventId ?? '',
        expiresAt: expiresAt,
        isActive: isActive,
      ),
      failure: 'Could not update promo',
    );
  }

  Future<void> deletePromo(String id) async {
    final response = await _client.delete(
      endpoint: EndPoint.promoById(id),
      headers: _authorizedHeaders,
    );
    final body = response.data;
    if (body is Map && body['success'] == false) {
      throw StateError(body['message']?.toString() ?? 'Could not delete promo');
    }
  }

  static Map<String, dynamic> mutationBody({
    required String code,
    required String discountType,
    required double discountValue,
    required int maxUses,
    String? clubId,
    String? eventId,
    DateTime? expiresAt,
    bool? isActive,
    bool isUpdate = false,
  }) {
    final body = <String, dynamic>{
      'code': code.trim().toUpperCase(),
      'discountType': discountType,
      'discountValue': _jsonNumber(discountValue),
      'maxUses': maxUses,
    };
    final scopedClub = clubId?.trim();
    final scopedEvent = eventId?.trim();
    if (isUpdate) {
      body['clubId'] = (scopedClub != null && scopedClub.isNotEmpty)
          ? scopedClub
          : null;
      body['eventId'] = (scopedEvent != null && scopedEvent.isNotEmpty)
          ? scopedEvent
          : null;
      body['expiresAt'] = expiresAt?.toUtc().toIso8601String();
      body['isActive'] = isActive ?? true;
    } else {
      if (scopedClub != null && scopedClub.isNotEmpty) body['clubId'] = scopedClub;
      if (scopedEvent != null && scopedEvent.isNotEmpty) {
        body['eventId'] = scopedEvent;
      }
      if (expiresAt != null) {
        body['expiresAt'] = expiresAt.toUtc().toIso8601String();
      }
    }
    return body;
  }

  PromoDataModel _promoFromResponse(
    dynamic body, {
    required PromoDataModel fallback,
    required String failure,
  }) {
    final map = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    if (map['success'] == false) {
      throw StateError(map['message']?.toString() ?? failure);
    }
    final data = map['data'];
    if (data is Map) {
      final promo = PromoDataModel.fromJson(Map<String, dynamic>.from(data));
      if (promo.code.isNotEmpty) return promo;
    }
    return fallback;
  }

  Map<String, dynamic> get _authorizedHeaders {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static num _jsonNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt();
    return value;
  }
}
