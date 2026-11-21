import 'package:bookdianight_app/app/core/explore/model/event_offer_model.dart';
import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/network/base_client.dart';
import 'package:bookdianight_app/app/core/network/end_point.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';

class ClubPackageModel {
  const ClubPackageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.capacity,
    required this.price,
    required this.currency,
    required this.features,
  });

  final String id;
  final String name;
  final String description;
  final int capacity;
  final String price;
  final String currency;
  final List<String> features;

  String get priceLabel {
    final amount = price.trim();
    if (amount.isEmpty) return '€0';
    return '€$amount';
  }

  factory ClubPackageModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    return ClubPackageModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      capacity: int.tryParse('${json['capacity']}') ?? 0,
      price: json['price']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'EUR',
      features: rawFeatures is List
          ? rawFeatures.map((item) => item.toString()).toList()
          : const [],
    );
  }
}

class ClubPurchaseResult {
  const ClubPurchaseResult({
    required this.orderId,
    required this.bookingId,
    required this.buyerTotal,
    required this.currency,
    required this.packageName,
  });

  final String orderId;
  final String bookingId;
  final String buyerTotal;
  final String currency;
  final String packageName;

  factory ClubPurchaseResult.fromJson(Map<String, dynamic> json) {
    final order = json['order'] is Map
        ? Map<String, dynamic>.from(json['order'] as Map)
        : <String, dynamic>{};
    final booking = json['booking'] is Map
        ? Map<String, dynamic>.from(json['booking'] as Map)
        : <String, dynamic>{};
    final eventPurchase = json['eventPurchase'] is Map
        ? Map<String, dynamic>.from(json['eventPurchase'] as Map)
        : <String, dynamic>{};
    final modulePurchase = json['modulePurchase'] is Map
        ? Map<String, dynamic>.from(json['modulePurchase'] as Map)
        : <String, dynamic>{};
    final eventModulePurchase = json['eventModulePurchase'] is Map
        ? Map<String, dynamic>.from(json['eventModulePurchase'] as Map)
        : <String, dynamic>{};
    final bookingId = _firstId([
      json['bookingId'],
      booking['id'],
      eventPurchase['id'],
      modulePurchase['id'],
      eventModulePurchase['id'],
      order['bookingId'],
    ]);
    final orderId = _firstId([
      json['orderId'],
      json['orderID'],
      order['id'],
    ]);
    return ClubPurchaseResult(
      orderId: orderId.isNotEmpty
          ? orderId
          : _firstId([
              if (json['id']?.toString() != bookingId) json['id'],
            ]),
      bookingId: bookingId,
      buyerTotal: order['buyerTotal']?.toString() ?? '0',
      currency: order['currency']?.toString() ?? 'EUR',
      packageName: booking['packageName']?.toString() ?? '',
    );
  }

  static String _firstId(List<dynamic> values) {
    for (final value in values) {
      final id = value?.toString().trim() ?? '';
      if (id.isNotEmpty) return id;
    }
    return '';
  }
}

class ClubPurchaseRepository {
  final BaseClient _client = BaseClient();

  Map<String, dynamic> _authHeaders({String? idempotencyKey}) {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required before booking.');
    }
    return {
      'Authorization': 'Bearer $token',
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'Idempotency-Key': idempotencyKey,
    };
  }

  Future<double> fetchServiceCharge() async {
    final response = await _client.get(
      endpoint: EndPoint.serviceCharge,
      headers: _authHeaders(),
    );
    final amount = _dataMap(response.data)['amount'];
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '') ?? 0;
  }

  Future<List<ClubPackageModel>> fetchAvailability({
    required String clubId,
    required String startAt,
    required String endAt,
    required int guestCount,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.clubAvailability,
      params: {
        'clubId': clubId,
        'startAt': startAt,
        'endAt': endAt,
        'guestCount': guestCount,
      },
      headers: _authHeaders(),
    );
    final data = _dataMap(response.data);
    final packages = data['availablePackages'];
    if (packages is! List) return const [];
    return packages
        .whereType<Map>()
        .map((item) => ClubPackageModel.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<ClubPurchaseResult> createEventPurchase({
    required String eventId,
    required List<Map<String, dynamic>> friends,
    required String idempotencyKey,
    String? ticketTierId,
    String? promoCode,
  }) async {
    final response = await _client.post(
      endpoint: EndPoint.purchaseEvent,
      body: {
        'eventId': eventId,
        'friends': friends,
        if (ticketTierId != null && ticketTierId.trim().isNotEmpty)
          'ticketTierId': ticketTierId.trim(),
        if (promoCode != null && promoCode.trim().isNotEmpty)
          'promoCode': promoCode.trim(),
      },
      headers: _authHeaders(idempotencyKey: idempotencyKey),
    );
    return ClubPurchaseResult.fromJson(_dataMap(response.data));
  }

  Future<ClubPurchaseResult> createModulePurchase({
    required String eventId,
    required String moduleId,
    required String idempotencyKey,
    int quantity = 1,
    int guestCount = 1,
    String? dateTime,
    String? promoCode,
  }) async {
    final response = await _client.post(
      endpoint: EndPoint.purchaseModule,
      body: {
        'eventId': eventId.trim(),
        'moduleId': moduleId.trim(),
        'quantity': quantity,
        'guestCount': guestCount,
        if (dateTime != null && dateTime.trim().isNotEmpty)
          'dateTime': dateTime.trim(),
        if (promoCode != null && promoCode.trim().isNotEmpty)
          'promoCode': promoCode.trim(),
      },
      headers: _authHeaders(idempotencyKey: idempotencyKey),
    );
    return ClubPurchaseResult.fromJson(_dataMap(response.data));
  }

  Future<PromoValidationModel> validatePromo({
    required String code,
    required double originalAmount,
    String? eventId,
    String? clubId,
  }) async {
    final response = await _client.post(
      endpoint: EndPoint.promoValidate,
      body: {
        'code': code.trim(),
        'originalAmount': originalAmount,
        if (eventId != null && eventId.trim().isNotEmpty) 'eventId': eventId,
        if (clubId != null && clubId.trim().isNotEmpty) 'clubId': clubId,
      },
      headers: _authHeaders(),
    );
    final body = response.data;
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    if (map['success'] == false) {
      throw StateError(map['message']?.toString() ?? 'Promo code is not valid');
    }
    return PromoValidationModel.fromJson(_dataMap(map));
  }

  Future<ClubPurchaseResult> createPurchase({
    required String clubPackageId,
    required String startAt,
    required String endAt,
    required int guestCount,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      endpoint: EndPoint.purchaseClub,
      body: {
        'clubPackageId': clubPackageId,
        'startAt': startAt,
        'endAt': endAt,
        'guestCount': guestCount,
      },
      headers: _authHeaders(idempotencyKey: idempotencyKey),
    );
    return ClubPurchaseResult.fromJson(_dataMap(response.data));
  }

  Future<String> createPaymentIntent({
    required String orderId,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      endpoint: EndPoint.paymentIntent,
      body: {'orderId': orderId},
      headers: _authHeaders(idempotencyKey: idempotencyKey),
    );
    final secret = _dataMap(response.data)['clientSecret']?.toString() ?? '';
    if (secret.isEmpty) {
      throw StateError('Payment could not be started.');
    }
    return secret;
  }

  Map<String, dynamic> _dataMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }
}
