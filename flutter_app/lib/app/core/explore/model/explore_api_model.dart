import 'package:bookdianight_app/app/core/utils/cst_time.dart';
import 'event_commerce_model.dart';
import 'event_offer_model.dart';

class ExploreQueryModel {
  final String? type;
  final String? categoryType;
  final DateTime? date;
  final String? dateFilter;
  final double? latitude;
  final double? longitude;
  final double? minimumPrice;
  final double? maximumPrice;
  final bool? isFree;
  final bool? isPopular;
  final double? ratings;
  final bool? isVip;
  final String? search;
  final String? genre;
  final String? city;
  final String? mood;
  final int page;
  final int limit;
  final String? sort;

  const ExploreQueryModel({
    this.type,
    this.categoryType,
    this.date,
    this.dateFilter,
    this.latitude,
    this.longitude,
    this.minimumPrice,
    this.maximumPrice,
    this.isFree,
    this.isPopular,
    this.ratings,
    this.isVip,
    this.search,
    this.genre,
    this.city,
    this.mood,
    this.page = 1,
    this.limit = 10,
    this.sort,
  });

  Map<String, dynamic> toQueryParameters() {
    final normalizedType = type?.trim().toUpperCase();
    final normalizedCategory = categoryType?.trim().toUpperCase();
    final normalizedSearch = search?.trim();
    final genres = genre?.trim() ?? '';
    return {
      if (normalizedType != null &&
          (normalizedType == 'CLUB' || normalizedType == 'EVENT'))
        'type': normalizedType,
      if (normalizedCategory != null && normalizedCategory.isNotEmpty)
        'categoryType': normalizedCategory,
      if (dateFilter != null && dateFilter!.trim().isNotEmpty)
        'dateFilter': dateFilter!.trim(),
      if ((dateFilter == null || dateFilter!.trim().isEmpty) && date != null)
        'date': date!.toUtc().toIso8601String(),
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      if (isFree == true) 'isFree': true,
      if (isFree != true && minimumPrice != null) 'minPrice': minimumPrice,
      if (isFree != true && maximumPrice != null) 'maxPrice': maximumPrice,
      if (isPopular != null) 'isPopular': isPopular,
      if (ratings != null) 'ratings': ratings,
      if (isVip != null) 'isVip': isVip,
      if (normalizedSearch != null && normalizedSearch.isNotEmpty)
        'search': normalizedSearch,
      if (genres.isNotEmpty) 'genres': genres,
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      if (mood != null && mood!.trim().isNotEmpty) 'mood': mood!.trim(),
      'page': page,
      'limit': limit,
      if (sort != null && sort!.trim().isNotEmpty) 'sort': sort!.trim(),
    };
  }
}

class ExploreItemModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final double? review;
  final String image;
  final String? location;
  final double? price;
  final double? minimumPrice;
  final double? maximumPrice;
  final String? currency;
  final String? status;
  final DateTime? startAt;
  final DateTime? endAt;
  final String orderId;
  final bool isWishlist;
  final bool isVip;

  const ExploreItemModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.review,
    this.image = '',
    this.location,
    this.price,
    this.minimumPrice,
    this.maximumPrice,
    this.currency,
    this.status,
    this.startAt,
    this.endAt,
    this.orderId = '',
    this.isWishlist = false,
    this.isVip = false,
  });

  factory ExploreItemModel.fromJson(Map<String, dynamic> json) {
    final thumbnail = json['thumbnail'];
    final locationValue = json['location'];
    final priceRange = json['priceRange'];
    final rangeMin = priceRange is Map
        ? _toDouble(priceRange['minPrice'] ?? priceRange['minimumPrice'])
        : null;
    final rangeMax = priceRange is Map
        ? _toDouble(priceRange['maxPrice'] ?? priceRange['maximumPrice'])
        : null;

    return ExploreItemModel(
      id: json['id']?.toString() ?? '',
      name:
          (json['name'] ?? json['eventName'] ?? json['clubName'])?.toString() ??
          '',
      latitude: _toDouble(json['lat']) ?? 0,
      longitude: _toDouble(json['lng']) ?? 0,
      type: json['type']?.toString().toUpperCase() ?? '',
      review: _toDouble(json['review'] ?? json['rating']),
      image:
          thumbnail?.toString() ??
          json['image']?.toString() ??
          json['imageUrl']?.toString() ??
          '',
      location: locationValue is Map
          ? (locationValue['address'] ?? locationValue['name'])?.toString()
          : (locationValue ?? json['address'])?.toString(),
      // EVENT uses flat `price`; CLUB uses `priceRange.minPrice`
      price: _toDouble(json['price']),
      minimumPrice:
          rangeMin ?? _toDouble(json['minPrice'] ?? json['minimumPrice']),
      maximumPrice:
          rangeMax ?? _toDouble(json['maxPrice'] ?? json['maximumPrice']),
      currency: json['currency']?.toString(),
      status: json['status']?.toString(),
      startAt: DateTime.tryParse(
        (json['startAt'] ?? json['eventStartAt'])?.toString() ?? '',
      ),
      endAt: DateTime.tryParse(
        (json['endAt'] ?? json['eventEndAt'])?.toString() ?? '',
      ),
      orderId: (json['orderId'] ?? json['orderID'])?.toString() ?? '',
      isWishlist: json['isWishlist'] == true,
      isVip: json['isVip'] == true,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class ExploreMetaModel {
  final int total;
  final int totalPages;

  const ExploreMetaModel({this.total = 0, this.totalPages = 0});

  factory ExploreMetaModel.fromJson(Map<String, dynamic> json) {
    return ExploreMetaModel(
      total: _toInt(json['total']),
      totalPages: _toInt(json['totalPages']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ExploreResponseModel {
  final bool success;
  final String message;
  final ExploreMetaModel meta;
  final List<ExploreItemModel> data;

  const ExploreResponseModel({
    required this.success,
    required this.message,
    required this.meta,
    required this.data,
  });

  factory ExploreResponseModel.fromJson(Map<String, dynamic> json) {
    final metaJson = json['meta'];
    final dataJson = json['data'];
    return ExploreResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      meta: ExploreMetaModel.fromJson(
        metaJson is Map
            ? Map<String, dynamic>.from(metaJson)
            : const <String, dynamic>{},
      ),
      data: dataJson is List
          ? dataJson
                .whereType<Map>()
                .map(
                  (item) => ExploreItemModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class ExploreOpeningHourModel {
  final String? id;
  final int dayOfWeek;
  final bool isClosed;
  final DateTime openTime;
  final DateTime closeTime;
  final bool closesNextDay;

  const ExploreOpeningHourModel({
    this.id,
    required this.dayOfWeek,
    required this.isClosed,
    required this.openTime,
    required this.closeTime,
    required this.closesNextDay,
  });

  static ExploreOpeningHourModel? tryFromJson(Map<String, dynamic> json) {
    final openRaw = json['openTime']?.toString() ?? '';
    final closeRaw = json['closeTime']?.toString() ?? '';
    if (openRaw.isEmpty || closeRaw.isEmpty) return null;
    final openTime = clubClockFromIso(openRaw);
    final closeTime = clubClockFromIso(closeRaw);
    return ExploreOpeningHourModel(
      id: json['id']?.toString(),
      dayOfWeek: _toInt(json['dayOfWeek']),
      isClosed: json['isClosed'] == true,
      openTime: openTime,
      closeTime: closeTime,
      closesNextDay: json['closesNextDay'] == true,
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ExplorePackageModel {
  final String? id;
  final String name;
  final String description;
  final int capacity;
  final double price;
  final String currency;
  final List<String> features;
  final int sortOrder;
  final bool isActive;

  const ExplorePackageModel({
    this.id,
    required this.name,
    required this.description,
    required this.capacity,
    required this.price,
    required this.currency,
    required this.features,
    required this.sortOrder,
    required this.isActive,
  });

  factory ExplorePackageModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    return ExplorePackageModel(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      capacity: _toInt(json['capacity']),
      price: _toDouble(json['price']) ?? 0,
      currency: json['currency']?.toString() ?? '',
      features: rawFeatures is List
          ? rawFeatures
                .map((feature) => feature.toString())
                .toList(growable: false)
          : const [],
      sortOrder: _toInt(json['sortOrder']),
      isActive: json['isActive'] != false,
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class ExploreDetailModel {
  final String id;
  final Map<String, dynamic>? organizer;
  final Map<String, dynamic>? linkedClub;
  final String? clubId;
  final int? followerCount;
  final String name;
  final String description;
  final String thumbnail;
  final List<String> images;
  final String dressCode;
  final String location;
  final String? eventStatus;
  final DateTime? startAt;
  final DateTime? endAt;
  final double? eventPrice;
  final String? currency;
  final bool? isRecurring;
  final bool? isVip;
  final double? latitude;
  final double? longitude;
  final double? aggregateRating;
  final int? totalReviews;
  final bool isWishlist;
  final List<ExploreOpeningHourModel> openingHours;
  final List<ExplorePackageModel> packages;
  final List<EventTicketTierModel> ticketTiers;
  final List<EventLineupArtistModel> lineup;
  final List<String> musicGenres;
  final List<EventVipModuleModel> modules;
  final EventGuestListModel? guestList;
  final List<EventHostModel> hosts;
  final List<String> moodTags;
  final bool bookingsClosed;

  const ExploreDetailModel({
    required this.id,
    this.organizer,
    this.linkedClub,
    this.clubId,
    this.followerCount,
    required this.name,
    required this.description,
    required this.thumbnail,
    required this.images,
    required this.dressCode,
    required this.location,
    this.eventStatus,
    this.startAt,
    this.endAt,
    this.eventPrice,
    this.currency,
    required this.isRecurring,
    required this.isVip,
    required this.latitude,
    required this.longitude,
    this.aggregateRating,
    required this.totalReviews,
    this.isWishlist = false,
    required this.openingHours,
    required this.packages,
    this.ticketTiers = const [],
    this.lineup = const [],
    this.musicGenres = const [],
    this.modules = const [],
    this.guestList,
    this.hosts = const [],
    this.moodTags = const [],
    this.bookingsClosed = false,
  });

  String? get associatedClubId =>
      clubId ??
      linkedClub?['id']?.toString() ??
      organizer?['clubId']?.toString();

  /// Buyer-facing start price: cheapest ticket tier, else `eventPrice`.
  double? get startingPrice {
    final prices = ticketTiers
        .expand((tier) => tier.flattened)
        .map((tier) => tier.price)
        .toList();
    if (prices.isNotEmpty) {
      prices.sort();
      return prices.first;
    }
    return eventPrice;
  }

  bool get hasMultipleTicketPrices {
    final prices = ticketTiers
        .expand((tier) => tier.flattened)
        .map((tier) => tier.price)
        .toSet();
    return prices.length > 1;
  }

  factory ExploreDetailModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final rawHours = json['clubOpeningHours'];
    final rawPackages = json['clubPackages'];
    return ExploreDetailModel(
      id: json['id']?.toString() ?? '',
      organizer: (json['organizer'] ?? json['club']) is Map
          ? Map<String, dynamic>.from(
              (json['organizer'] ?? json['club']) as Map,
            )
          : null,
      linkedClub: json['club'] is Map
          ? Map<String, dynamic>.from(json['club'] as Map)
          : null,
      clubId: json['clubId']?.toString(),
      followerCount: _toIntOrNull(json['followerCount']),
      name: json['name']?.toString() ?? json['eventName']?.toString() ?? '',
      description:
          json['description']?.toString() ??
          json['eventDescription']?.toString() ??
          '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      images: rawImages is List
          ? rawImages
                .map((image) => image.toString())
                .where((image) => image.trim().isNotEmpty)
                .toList(growable: false)
          : const [],
      dressCode: json['dressCode']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      eventStatus: json['eventStatus']?.toString(),
      startAt: DateTime.tryParse(json['startAt']?.toString() ?? ''),
      endAt: DateTime.tryParse(json['endAt']?.toString() ?? ''),
      eventPrice: _toDouble(json['eventPrice'] ?? json['price']),
      currency: json['currency']?.toString(),
      isRecurring: json['isRecurring'] is bool
          ? json['isRecurring'] as bool
          : null,
      isVip: json['isVip'] is bool ? json['isVip'] as bool : null,
      latitude: _toDouble(json['lat']),
      longitude: _toDouble(json['lng']),
      aggregateRating: _toDouble(json['aggregateRating'] ?? json['review']),
      totalReviews: _toIntOrNull(json['totalReviews']),
      isWishlist: json['isWishlist'] == true,
      openingHours: rawHours is List
          ? rawHours
                .whereType<Map>()
                .map(
                  (hours) => ExploreOpeningHourModel.tryFromJson(
                    Map<String, dynamic>.from(hours),
                  ),
                )
                .whereType<ExploreOpeningHourModel>()
                .toList(growable: false)
          : const [],
      packages: rawPackages is List
          ? rawPackages
                .whereType<Map>()
                .map(
                  (package) => ExplorePackageModel.fromJson(
                    Map<String, dynamic>.from(package),
                  ),
                )
                .where((package) => package.name.trim().isNotEmpty)
                .toList(growable: false)
          : const [],
      ticketTiers: EventTicketTierModel.listFrom(
        json['ticketTiers'] ?? json['tiers'],
      ),
      lineup: EventLineupArtistModel.listFrom(
        json['lineup'] ?? json['artists'],
      ),
      musicGenres: stringListFrom(json['musicGenres'] ?? json['genres']),
      modules: EventVipModuleModel.listFrom(json['modules']),
      guestList: EventGuestListModel.tryFrom(json['guestList']),
      hosts: EventHostModel.listFrom(json['hosts']),
      moodTags: stringListFrom(json['moodTags'] ?? json['moods']),
      bookingsClosed: json['bookingsClosed'] == true,
    );
  }

  static int? _toIntOrNull(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class ExploreDetailResponseModel {
  final bool success;
  final String message;
  final ExploreDetailModel? data;

  const ExploreDetailResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  factory ExploreDetailResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return ExploreDetailResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: rawData is Map
          ? ExploreDetailModel.fromJson(Map<String, dynamic>.from(rawData))
          : null,
    );
  }
}
