import '../../../../core/explore/model/event_commerce_model.dart';
import '../../../../core/explore/model/event_offer_model.dart';

class EventDataModel {
  const EventDataModel({
    required this.id,
    required this.userId,
    required this.eventName,
    required this.eventDescription,
    required this.thumbnail,
    required this.images,
    required this.eventStatus,
    required this.latitude,
    required this.longitude,
    this.location = '',
    required this.startAt,
    required this.endAt,
    required this.dressCode,
    required this.eventPrice,
    required this.currency,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.deactivatedAt,
    this.clubId,
    this.clubName = '',
    this.ticketTiers = const [],
    this.lineup = const [],
    this.musicGenres = const [],
    this.categoryType = 'CLUB',
    this.clubHostStatus = 'NONE',
    this.bookingsClosed = false,
    this.hosts = const [],
  });

  final String id;
  final String userId;
  final String eventName;
  final String eventDescription;
  final String thumbnail;
  final List<String> images;
  final String eventStatus;
  final double latitude;
  final double longitude;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final String dressCode;
  final double eventPrice;
  final String currency;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deactivatedAt;
  final String? clubId;
  final String clubName;
  final List<EventTicketTierModel> ticketTiers;
  final List<EventLineupArtistModel> lineup;
  final List<String> musicGenres;
  final String categoryType;
  final String clubHostStatus;
  final bool bookingsClosed;
  final List<EventHostModel> hosts;

  factory EventDataModel.fromJson(Map<String, dynamic> json) {
    final deactivatedAt = _readDateTime(json['deactivatedAt']);
    final club = json['club'] is Map
        ? Map<String, dynamic>.from(json['club'] as Map)
        : const <String, dynamic>{};
    return EventDataModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      eventName: _firstText(json['eventName'], json['name']),
      eventDescription: json['eventDescription']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      images: _readStringList(json['images']),
      eventStatus: json['eventStatus']?.toString().trim().toUpperCase() ?? '',
      latitude: _readDouble(json['lat']),
      longitude: _readDouble(json['lng']),
      location: json['location']?.toString() ?? '',
      startAt:
          _readDateTime(json['startAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endAt:
          _readDateTime(json['endAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      dressCode: json['dressCode']?.toString() ?? '',
      eventPrice: _readDouble(json['eventPrice'] ?? json['price']),
      currency: json['currency']?.toString() ?? 'EUR',
      isActive: _readNullableBool(json['isActive']) ?? deactivatedAt == null,
      createdAt: _readDateTime(json['createdAt']),
      updatedAt: _readDateTime(json['updatedAt']),
      deactivatedAt: deactivatedAt,
      clubId: (json['clubId'] ?? json['club_id'] ?? club['id'])?.toString(),
      clubName: (json['clubName'] ?? json['club_name'] ?? club['name'] ?? '')
          .toString(),
      ticketTiers: EventTicketTierModel.listFrom(
        json['ticketTiers'] ??
            json['tiers'] ??
            json['ticket_tiers'] ??
            json['eventTicketTiers'] ??
            json['EventTicketTier'],
      ),
      lineup: EventLineupArtistModel.listFrom(
        json['lineup'] ??
            json['artists'] ??
            json['eventLineup'] ??
            json['EventLineup'] ??
            json['lineUp'],
      ),
      musicGenres: _readStringList(
        json['musicGenres'] ?? json['genres'] ?? json['music_genres'],
      ),
      categoryType: (json['categoryType'] ?? 'CLUB').toString().trim().toUpperCase(),
      clubHostStatus:
          (json['clubHostStatus'] ?? 'NONE').toString().trim().toUpperCase(),
      bookingsClosed: json['bookingsClosed'] == true,
      hosts: EventHostModel.listFrom(json['hosts']),
    );
  }

  EventDataModel copyWith({
    String? clubId,
    String? clubName,
    List<EventTicketTierModel>? ticketTiers,
    List<EventLineupArtistModel>? lineup,
    List<String>? musicGenres,
    bool? bookingsClosed,
    List<EventHostModel>? hosts,
  }) {
    return EventDataModel(
      id: id,
      userId: userId,
      eventName: eventName,
      eventDescription: eventDescription,
      thumbnail: thumbnail,
      images: images,
      eventStatus: eventStatus,
      latitude: latitude,
      longitude: longitude,
      location: location,
      startAt: startAt,
      endAt: endAt,
      dressCode: dressCode,
      eventPrice: eventPrice,
      currency: currency,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deactivatedAt: deactivatedAt,
      clubId: clubId ?? this.clubId,
      clubName: clubName ?? this.clubName,
      ticketTiers: ticketTiers ?? this.ticketTiers,
      lineup: lineup ?? this.lineup,
      musicGenres: musicGenres ?? this.musicGenres,
      categoryType: categoryType,
      clubHostStatus: clubHostStatus,
      bookingsClosed: bookingsClosed ?? this.bookingsClosed,
      hosts: hosts ?? this.hosts,
    );
  }

  /// Owner GET /event/:id currently omits ticketTiers/lineup. Public explore
  /// still returns the active rows, so fill only the missing arrays from it.
  EventDataModel withOffersFrom(EventDataModel other) {
    return copyWith(
      ticketTiers: ticketTiers.isNotEmpty ? ticketTiers : other.ticketTiers,
      lineup: lineup.isNotEmpty ? lineup : other.lineup,
      musicGenres: musicGenres.isNotEmpty ? musicGenres : other.musicGenres,
      bookingsClosed: bookingsClosed || other.bookingsClosed,
      hosts: hosts.isNotEmpty ? hosts : other.hosts,
    );
  }
}

class EventUpsertRequestModel {
  const EventUpsertRequestModel({
    required this.eventName,
    required this.eventDescription,
    required this.thumbnail,
    required this.images,
    required this.eventStatus,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.startAt,
    required this.endAt,
    required this.dressCode,
    required this.eventPrice,
    this.currency = 'EUR',
    this.isActive = true,
    this.clubId,
    this.ticketTiers = const [],
    this.lineup = const [],
    this.musicGenres = const [],
    this.categoryType = 'CLUB',
  });

  final String eventName;
  final String eventDescription;
  final String thumbnail;
  final List<String> images;
  final String eventStatus;
  final String location;
  final double latitude;
  final double longitude;
  final DateTime startAt;
  final DateTime endAt;
  final String dressCode;
  final double eventPrice;
  final String currency;
  final bool isActive;
  final String? clubId;
  final List<EventTicketTierModel> ticketTiers;
  final List<EventLineupArtistModel> lineup;
  final List<String> musicGenres;
  final String categoryType;

  Map<String, dynamic> toJson({required bool isUpdate}) {
    return {
      'eventName': eventName,
      'eventDescription': eventDescription,
      'thumbnail': thumbnail,
      'images': images,
      'eventStatus': eventStatus.trim().toUpperCase(),
      'location': location,
      'lat': latitude,
      'lng': longitude,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'dressCode': dressCode,
      'eventPrice': eventPrice,
      'currency': currency,
      if (isUpdate) 'isActive': isActive,
      if (clubId != null && clubId!.trim().isNotEmpty) 'clubId': clubId,
      if (ticketTiers.isNotEmpty)
        'ticketTiers': ticketTiers.map((tier) => tier.toPayload()).toList(),
      if (lineup.isNotEmpty)
        'lineup': lineup.map((artist) => artist.toPayload()).toList(),
      if (musicGenres.isNotEmpty) 'musicGenres': musicGenres,
      if (categoryType.trim().isNotEmpty)
        'categoryType': categoryType.trim().toUpperCase(),
    };
  }
}

class EventPaginationMetaModel {
  const EventPaginationMetaModel({this.total = 0, this.totalPages = 0});

  final int total;
  final int totalPages;

  factory EventPaginationMetaModel.fromJson(Map<String, dynamic> json) {
    return EventPaginationMetaModel(
      total: _readInt(json['total']),
      totalPages: _readInt(json['totalPages']),
    );
  }
}

class EventListResponseModel {
  const EventListResponseModel({
    required this.success,
    required this.message,
    required this.meta,
    required this.data,
  });

  final bool success;
  final String message;
  final EventPaginationMetaModel meta;
  final List<EventDataModel> data;

  factory EventListResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return EventListResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      meta: EventPaginationMetaModel.fromJson(
        json['meta'] is Map
            ? Map<String, dynamic>.from(json['meta'] as Map)
            : const {},
      ),
      data: rawData is List
          ? rawData
                .whereType<Map>()
                .map(
                  (item) =>
                      EventDataModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class EventDetailResponseModel {
  const EventDetailResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  final bool success;
  final String message;
  final EventDataModel? data;

  factory EventDetailResponseModel.fromJson(Map<String, dynamic> json) {
    return EventDetailResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map
          ? EventDataModel.fromJson(
              Map<String, dynamic>.from(json['data'] as Map),
            )
          : null,
    );
  }
}

class EventMutationResponseModel {
  const EventMutationResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  final bool success;
  final String message;
  final EventDataModel? data;

  factory EventMutationResponseModel.fromJson(Map<String, dynamic> json) {
    return EventMutationResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map
          ? EventDataModel.fromJson(
              Map<String, dynamic>.from(json['data'] as Map),
            )
          : null,
    );
  }
}

String _firstText(dynamic primary, dynamic fallback) {
  final first = primary?.toString().trim() ?? '';
  if (first.isNotEmpty) return first;
  return fallback?.toString().trim() ?? '';
}

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  final raw = value?.toString().trim() ?? '';
  return double.tryParse(raw) ?? 0;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _readDateTime(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '');
}

bool? _readNullableBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch (value?.toString().trim().toLowerCase()) {
    case 'true':
    case '1':
      return true;
    case 'false':
    case '0':
      return false;
    default:
      return null;
  }
}

List<String> _readStringList(dynamic value) {
  return (value as List?)
          ?.map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false) ??
      const [];
}
