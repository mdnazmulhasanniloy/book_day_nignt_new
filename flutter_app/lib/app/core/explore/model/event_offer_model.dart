import 'dart:convert';

class EventTicketTierModel {
  const EventTicketTierModel({
    this.id = '',
    required this.tierName,
    this.groupName = '',
    this.description = '',
    required this.price,
    required this.capacity,
    this.soldCount = 0,
    this.sortOrder = 0,
    this.startAt,
    this.endAt,
    this.isActive = true,
    this.remaining,
    this.currency = 'EUR',
    this.soldOut,
    this.children = const [],
  });

  final String id;
  final String tierName;
  final String groupName;
  final String description;
  final double price;
  final int capacity;
  final int soldCount;
  final int sortOrder;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final int? remaining;
  final String currency;
  final bool? soldOut;
  final List<EventTicketTierModel> children;

  int get remainingCount {
    if (remaining != null) return remaining!;
    return (capacity - soldCount).clamp(0, capacity);
  }

  bool get isSoldOut {
    if (soldOut != null) return soldOut!;
    return remainingCount <= 0;
  }

  bool get hasChildren => children.isNotEmpty;

  List<EventTicketTierModel> get flattened {
    return [this, for (final child in children) ...child.flattened];
  }

  factory EventTicketTierModel.fromJson(Map<String, dynamic> json) {
    return EventTicketTierModel(
      id: json['id']?.toString() ?? '',
      tierName: (json['tierName'] ?? json['name'] ?? '').toString().trim(),
      groupName: (json['groupName'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      price: _toDouble(json['price']),
      capacity: _toInt(json['capacity']),
      soldCount: _toInt(json['soldCount']),
      sortOrder: _toInt(json['sortOrder']),
      startAt: _toDate(json['startAt']),
      endAt: _toDate(json['endAt']),
      isActive: json['isActive'] != false,
      remaining: _toIntOrNull(
        json['remaining'] ?? json['remainingCapacity'] ?? json['available'],
      ),
      currency: json['currency']?.toString() ?? 'EUR',
      soldOut: json['soldOut'] is bool ? json['soldOut'] as bool : null,
      children: EventTicketTierModel.listFrom(json['children']),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      if (id.trim().isNotEmpty) 'id': id.trim(),
      'tierName': tierName,
      'price': price,
      'capacity': capacity,
      'sortOrder': sortOrder,
      if (groupName.trim().isNotEmpty) 'groupName': groupName.trim(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (startAt != null) 'startAt': startAt!.toUtc().toIso8601String(),
      if (endAt != null) 'endAt': endAt!.toUtc().toIso8601String(),
      'isActive': isActive,
    };
  }

  static List<EventTicketTierModel> listFrom(dynamic value) {
    final items = _asMaps(value)
        .map(EventTicketTierModel.fromJson)
        .where((item) => item.tierName.isNotEmpty)
        .toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }
}

class EventLineupArtistModel {
  const EventLineupArtistModel({
    this.id = '',
    this.artistId = '',
    required this.artistName,
    this.artistAvatar = '',
    this.audioPreviewUrl = '',
    this.isVerified = false,
    this.spotifyUrl = '',
    this.soundcloudUrl = '',
    this.sortOrder = 0,
    this.followerCount = 0,
  });

  final String id;
  final String artistId;
  final String artistName;
  final String artistAvatar;
  final String audioPreviewUrl;
  final bool isVerified;
  final String spotifyUrl;
  final String soundcloudUrl;
  final int sortOrder;
  final int followerCount;

  String get followId => artistId.trim().isNotEmpty ? artistId.trim() : '';

  String get externalUrl {
    for (final value in [spotifyUrl, soundcloudUrl, audioPreviewUrl]) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  factory EventLineupArtistModel.fromJson(Map<String, dynamic> json) {
    final nested = json['artist'] is Map
        ? Map<String, dynamic>.from(json['artist'] as Map)
        : const <String, dynamic>{};
    final nestedId = nested['id']?.toString().trim() ?? '';
    final nestedName = (nested['name'] ?? '').toString().trim();
    final nestedAvatar = (nested['avatar'] ?? '').toString();
    return EventLineupArtistModel(
      id: json['id']?.toString() ?? '',
      artistId: (json['artistId']?.toString() ?? nestedId).trim(),
      artistName: (json['artistName'] ?? json['name'] ?? nestedName)
          .toString()
          .trim(),
      artistAvatar: (json['artistAvatar'] ?? json['avatar'] ?? nestedAvatar)
          .toString(),
      audioPreviewUrl: (json['audioPreviewUrl'] ?? nested['audioPreviewUrl'])
              ?.toString() ??
          '',
      isVerified: json['isVerified'] == true || nested['isVerified'] == true,
      spotifyUrl: (json['spotifyUrl'] ??
              json['spotify'] ??
              nested['spotifyUrl'] ??
              nested['spotify'])
          ?.toString()
          .trim() ??
          '',
      soundcloudUrl: (json['soundcloudUrl'] ??
              json['soundcloud'] ??
              nested['soundcloudUrl'] ??
              nested['soundcloud'])
          ?.toString()
          .trim() ??
          '',
      sortOrder: _toInt(json['sortOrder']),
      followerCount: _toInt(nested['followerCount'] ?? json['followerCount']),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      if (id.trim().isNotEmpty) 'id': id.trim(),
      if (artistId.trim().isNotEmpty) 'artistId': artistId.trim(),
      'artistName': artistName,
      if (artistAvatar.trim().isNotEmpty) 'artistAvatar': artistAvatar.trim(),
      if (audioPreviewUrl.trim().isNotEmpty)
        'audioPreviewUrl': audioPreviewUrl.trim(),
      'isVerified': isVerified,
      if (spotifyUrl.trim().isNotEmpty) 'spotifyUrl': spotifyUrl.trim(),
      if (soundcloudUrl.trim().isNotEmpty) 'soundcloudUrl': soundcloudUrl.trim(),
      'sortOrder': sortOrder,
    };
  }

  static List<EventLineupArtistModel> listFrom(dynamic value) {
    final items = <EventLineupArtistModel>[];
    for (final row in _asRows(value)) {
      if (row is String && row.trim().isNotEmpty) {
        items.add(EventLineupArtistModel(artistName: row.trim()));
        continue;
      }
      if (row is Map) {
        final artist = EventLineupArtistModel.fromJson(
          Map<String, dynamic>.from(row),
        );
        if (artist.artistName.isNotEmpty) items.add(artist);
      }
    }
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }
}

class PromoValidationModel {
  const PromoValidationModel({
    required this.isValid,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.finalAmount,
  });

  final bool isValid;
  final String code;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final double finalAmount;

  factory PromoValidationModel.fromJson(Map<String, dynamic> json) {
    return PromoValidationModel(
      isValid: json['isValid'] == true,
      code: json['code']?.toString() ?? '',
      discountType: json['discountType']?.toString() ?? '',
      discountValue: _toDouble(json['discountValue']),
      discountAmount: _toDouble(json['discountAmount']),
      finalAmount: _toDouble(json['finalAmount']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '');
}

dynamic _unwrapList(dynamic value) {
  var current = value;
  if (current is String) {
    final trimmed = current.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        current = jsonDecode(trimmed);
      } catch (_) {
        return trimmed.contains(',')
            ? trimmed
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList()
            : [trimmed];
      }
    } else {
      return trimmed.contains(',')
          ? trimmed
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : [trimmed];
    }
  }
  if (current is Map) {
    return current['data'] ??
        current['items'] ??
        current['results'] ??
        current['ticketTiers'] ??
        current['tiers'] ??
        current['lineup'] ??
        current['artists'];
  }
  return current;
}

List<dynamic> _asRows(dynamic value) {
  final unwrapped = _unwrapList(value);
  if (unwrapped is! List) return const [];
  return unwrapped;
}

List<Map<String, dynamic>> _asMaps(dynamic value) {
  return _asRows(value)
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

List<String> stringListFrom(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
