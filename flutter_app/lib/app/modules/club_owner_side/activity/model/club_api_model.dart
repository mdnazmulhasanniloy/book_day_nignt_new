class ClubDataModel {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String thumbnail;
  final List<String> images;
  final String dressCode;
  final bool isRecurring;
  final bool isVip;
  final double lat;
  final double lng;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deactivatedAt;
  final bool isActive;
  final bool activeFlagPresent;
  final double? review;
  final double? minPrice;
  final List<Map<String, dynamic>> clubOpeningHours;
  final List<Map<String, dynamic>> clubPackages;

  ClubDataModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.thumbnail,
    required this.images,
    required this.dressCode,
    required this.isRecurring,
    required this.isVip,
    required this.lat,
    required this.lng,
    this.createdAt,
    this.updatedAt,
    this.deactivatedAt,
    this.isActive = true,
    this.activeFlagPresent = true,
    this.review,
    this.minPrice,
    required this.clubOpeningHours,
    required this.clubPackages,
  });

  factory ClubDataModel.fromJson(Map<String, dynamic> json) {
    final deactivatedAt = _readDateTime(json['deactivatedAt']);
    final hasActive = json.containsKey('isActive');
    final hasDeactivated = json.containsKey('deactivatedAt');
    return ClubDataModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      dressCode: json['dressCode']?.toString() ?? '',
      isRecurring: _readBool(json['isRecurring']),
      isVip: _readBool(json['isVip']),
      lat: _readDouble(json['lat']),
      lng: _readDouble(json['lng']),
      createdAt: _readDateTime(json['createdAt']),
      updatedAt: _readDateTime(json['updatedAt']),
      deactivatedAt: deactivatedAt,
      isActive: json['isActive'] is bool
          ? json['isActive'] as bool
          : deactivatedAt == null,
      activeFlagPresent: hasActive || hasDeactivated,
      review: json['review'] == null ? null : _readDouble(json['review']),
      minPrice: _readMinPrice(json['priceRange']),
      clubOpeningHours: _readMapList(json['clubOpeningHours']),
      clubPackages: _readMapList(json['clubPackages']),
    );
  }
}

class ClubListResponseModel {
  final bool success;
  final String message;
  final ClubPaginationMetaModel meta;
  final List<ClubDataModel> data;

  ClubListResponseModel({
    required this.success,
    required this.message,
    required this.meta,
    required this.data,
  });

  factory ClubListResponseModel.fromJson(Map<String, dynamic> json) {
    return ClubListResponseModel(
      success: json['success'] ?? false,
      message: json['message']?.toString() ?? '',
      meta: ClubPaginationMetaModel.fromJson(
        json['meta'] is Map
            ? Map<String, dynamic>.from(json['meta'] as Map)
            : const <String, dynamic>{},
      ),
      data:
          (json['data'] as List?)
              ?.whereType<Map>()
              .map(
                (item) =>
                    ClubDataModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false) ??
          const [],
    );
  }
}

class ClubPaginationMetaModel {
  final int total;
  final int totalPages;

  const ClubPaginationMetaModel({this.total = 0, this.totalPages = 0});

  factory ClubPaginationMetaModel.fromJson(Map<String, dynamic> json) {
    return ClubPaginationMetaModel(
      total: _readInt(json['total']),
      totalPages: _readInt(json['totalPages']),
    );
  }
}

class ClubDetailResponseModel {
  final bool success;
  final String message;
  final ClubDataModel? data;

  ClubDetailResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory ClubDetailResponseModel.fromJson(Map<String, dynamic> json) {
    return ClubDetailResponseModel(
      success: json['success'] ?? false,
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map
          ? ClubDataModel.fromJson(
              Map<String, dynamic>.from(json['data'] as Map),
            )
          : null,
    );
  }
}

double? _readMinPrice(dynamic value) {
  if (value is! Map || value['minPrice'] == null) return null;
  return _readDouble(value['minPrice']);
}

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}

DateTime? _readDateTime(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '');
}

List<Map<String, dynamic>> _readMapList(dynamic value) {
  return (value as List?)
          ?.whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false) ??
      const [];
}
