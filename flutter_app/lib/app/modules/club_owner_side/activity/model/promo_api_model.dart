class PromoDataModel {
  const PromoDataModel({
    this.id = '',
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxUses = 0,
    this.usedCount = 0,
    this.clubId = '',
    this.eventId = '',
    this.clubName = '',
    this.eventName = '',
    this.expiresAt,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String discountType;
  final double discountValue;
  final int maxUses;
  final int usedCount;
  final String clubId;
  final String eventId;
  final String clubName;
  final String eventName;
  final DateTime? expiresAt;
  final bool isActive;

  bool get isPercentage =>
      discountType.toUpperCase() == 'PERCENTAGE' ||
      discountType.toUpperCase() == 'PERCENT';

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  String get discountLabel {
    if (isPercentage) {
      final value = discountValue == discountValue.roundToDouble()
          ? discountValue.toInt().toString()
          : discountValue.toString();
      return '$value% off';
    }
    final value = discountValue == discountValue.roundToDouble()
        ? discountValue.toInt().toString()
        : discountValue.toStringAsFixed(2);
    return '€$value off';
  }

  String get appliesToLabel {
    if (eventName.isNotEmpty) return 'Event · $eventName';
    if (clubName.isNotEmpty) return 'Club · $clubName';
    if (eventId.isNotEmpty) return 'Limited to one event';
    if (clubId.isNotEmpty) return 'Limited to one club';
    return 'All clubs and events';
  }

  PromoDataModel copyWith({
    String? id,
    String? code,
    String? discountType,
    double? discountValue,
    int? maxUses,
    int? usedCount,
    String? clubId,
    String? eventId,
    String? clubName,
    String? eventName,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    bool? isActive,
  }) {
    return PromoDataModel(
      id: id ?? this.id,
      code: code ?? this.code,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      clubId: clubId ?? this.clubId,
      eventId: eventId ?? this.eventId,
      clubName: clubName ?? this.clubName,
      eventName: eventName ?? this.eventName,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      isActive: isActive ?? this.isActive,
    );
  }

  factory PromoDataModel.fromJson(Map<String, dynamic> json) {
    final club = json['club'] is Map
        ? Map<String, dynamic>.from(json['club'] as Map)
        : const <String, dynamic>{};
    final event = json['event'] is Map
        ? Map<String, dynamic>.from(json['event'] as Map)
        : const <String, dynamic>{};
    return PromoDataModel(
      id: json['id']?.toString() ?? '',
      code: (json['code'] ?? json['promoCode'] ?? '').toString().trim(),
      discountType: (json['discountType'] ?? json['type'] ?? '').toString(),
      discountValue: _toDouble(json['discountValue'] ?? json['value']),
      maxUses: _toInt(json['maxUses'] ?? json['usageLimit']),
      usedCount: _toInt(
        json['usedCount'] ??
            json['usageCount'] ??
            json['currentUses'] ??
            json['timesUsed'],
      ),
      clubId: _nullableId(json['clubId'] ?? club['id']),
      eventId: _nullableId(json['eventId'] ?? event['id']),
      clubName: (json['clubName'] ?? club['name'] ?? '').toString(),
      eventName:
          (json['eventName'] ?? event['eventName'] ?? event['name'] ?? '')
              .toString(),
      expiresAt: _toDate(json['expiresAt'] ?? json['expiryDate']),
      isActive: json['isActive'] != false && json['active'] != false,
    );
  }

  static List<PromoDataModel> listFrom(dynamic value) {
    var raw = value;
    if (raw is Map) {
      raw =
          raw['data'] ??
          raw['promos'] ??
          raw['items'] ??
          raw['results'] ??
          raw['promoCodes'];
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => PromoDataModel.fromJson(Map<String, dynamic>.from(row)))
        .where((item) => item.code.isNotEmpty)
        .toList(growable: false);
  }
}

class PromoListResponseModel {
  const PromoListResponseModel({
    required this.success,
    required this.message,
    required this.data,
    this.total = 0,
    this.totalPages = 0,
  });

  final bool success;
  final String message;
  final List<PromoDataModel> data;
  final int total;
  final int totalPages;

  factory PromoListResponseModel.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : const <String, dynamic>{};
    return PromoListResponseModel(
      success: json['success'] != false,
      message: json['message']?.toString() ?? '',
      data: PromoDataModel.listFrom(json['data'] ?? json),
      total: _toInt(meta['total']),
      totalPages: _toInt(meta['totalPages']),
    );
  }
}

String _nullableId(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  return text;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
