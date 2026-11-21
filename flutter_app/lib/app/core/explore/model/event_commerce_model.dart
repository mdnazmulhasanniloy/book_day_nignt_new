import 'event_offer_model.dart';

class EventVipModuleModel {
  const EventVipModuleModel({
    this.id = '',
    this.eventId = '',
    this.name = '',
    this.image,
    this.description = '',
    this.maxGuests = 0,
    this.startingPrice = '',
    this.minSpend = '',
    this.deposit = '',
    this.currency = 'EUR',
    this.quantity = 0,
    this.remaining = 0,
    this.venueArea = '',
    this.includedExtras = const [],
    this.optionalExtras = const [],
    this.status = 'AVAILABLE',
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String eventId;
  final String name;
  final String? image;
  final String description;
  final int maxGuests;
  final String startingPrice;
  final String minSpend;
  final String deposit;
  final String currency;
  final int quantity;
  final int remaining;
  final String venueArea;
  final List<String> includedExtras;
  final List<String> optionalExtras;
  final String status;
  final int sortOrder;
  final bool isActive;

  String get statusKey => status.trim().toUpperCase();

  bool get isSoldOut =>
      statusKey == 'SOLD_OUT' || (remaining <= 0 && quantity > 0);

  bool get isUnavailable => statusKey == 'UNAVAILABLE' || !isActive;

  bool get canBook => isActive && !isSoldOut && !isUnavailable;

  String get priceLabel {
    final amount = startingPrice.trim();
    if (amount.isEmpty) return '';
    return amount.startsWith('€') ? amount : '€$amount';
  }

  String get statusLabel {
    switch (statusKey) {
      case 'LIMITED':
        return 'Limited';
      case 'SOLD_OUT':
        return 'Sold out';
      case 'UNAVAILABLE':
        return 'Unavailable';
      default:
        return 'Available';
    }
  }

  factory EventVipModuleModel.fromJson(Map<String, dynamic> json) {
    final image = json['image']?.toString().trim();
    return EventVipModuleModel(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      image: image == null || image.isEmpty ? null : image,
      description: json['description']?.toString() ?? '',
      maxGuests: _toInt(json['maxGuests']),
      startingPrice: json['startingPrice']?.toString() ?? '',
      minSpend: json['minSpend']?.toString() ?? '',
      deposit: json['deposit']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'EUR',
      quantity: _toInt(json['quantity']),
      remaining: _toInt(json['remaining']),
      venueArea: json['venueArea']?.toString() ?? '',
      includedExtras: stringListFrom(json['includedExtras']),
      optionalExtras: stringListFrom(json['optionalExtras']),
      status: (json['status'] ?? 'AVAILABLE').toString(),
      sortOrder: _toInt(json['sortOrder']),
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toPayload({bool includeId = false}) {
    return {
      if (includeId && id.trim().isNotEmpty) 'id': id.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'maxGuests': maxGuests,
      'startingPrice': startingPrice.trim(),
      'minSpend': minSpend.trim(),
      'deposit': deposit.trim(),
      'currency': currency.trim().isEmpty ? 'EUR' : currency.trim(),
      'quantity': quantity,
      if (venueArea.trim().isNotEmpty) 'venueArea': venueArea.trim(),
      'includedExtras': includedExtras,
      'optionalExtras': optionalExtras,
      'status': statusKey.isEmpty ? 'AVAILABLE' : statusKey,
      'sortOrder': sortOrder,
      'isActive': isActive,
      if (image != null && image!.trim().isNotEmpty) 'image': image!.trim(),
    };
  }

  static List<EventVipModuleModel> listFrom(dynamic value) {
    if (value is! List) return const [];
    final items = value
        .whereType<Map>()
        .map((row) => EventVipModuleModel.fromJson(Map<String, dynamic>.from(row)))
        .where((item) => item.id.isNotEmpty || item.name.isNotEmpty)
        .toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }
}

class EventGuestListFallback {
  const EventGuestListFallback({
    this.type = '',
    this.id = '',
    this.label = '',
  });

  final String type;
  final String id;
  final String label;

  bool get isTicket => type.toUpperCase() == 'TICKET_TIER';
  bool get isModule => type.toUpperCase() == 'MODULE';

  factory EventGuestListFallback.fromJson(Map<String, dynamic> json) {
    return EventGuestListFallback(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPayload() => {
    'type': type.trim().toUpperCase(),
    'id': id.trim(),
    if (label.trim().isNotEmpty) 'label': label.trim(),
  };
}

class EventGuestListUsed {
  const EventGuestListUsed({
    this.men = 0,
    this.women = 0,
    this.other = 0,
    this.total = 0,
  });

  final int men;
  final int women;
  final int other;
  final int total;

  factory EventGuestListUsed.fromJson(Map<String, dynamic> json) {
    return EventGuestListUsed(
      men: _toInt(json['men'] ?? json['menCount']),
      women: _toInt(json['women'] ?? json['womenCount']),
      other: _toInt(json['other'] ?? json['otherCount'] ?? json['others']),
      total: _toInt(json['total'] ?? json['totalCount']),
    );
  }
}

class EventGuestListModel {
  const EventGuestListModel({
    this.isOpen = false,
    this.remainingMale,
    this.remainingFemale,
    this.remainingTotal,
    this.arrivalTimes = const [],
    this.cutoffAt,
    this.dressCode = '',
    this.notes = '',
    this.idRequired = false,
    this.fallbacks = const [],
    this.used,
  });

  final bool isOpen;
  final int? remainingMale;
  final int? remainingFemale;
  final int? remainingTotal;
  final List<String> arrivalTimes;
  final DateTime? cutoffAt;
  final String dressCode;
  final String notes;
  final bool idRequired;
  final List<EventGuestListFallback> fallbacks;
  final EventGuestListUsed? used;

  factory EventGuestListModel.fromJson(Map<String, dynamic> json) {
    final rawFallbacks = json['fallbacks'];
    final rawUsed = json['used'];
    return EventGuestListModel(
      isOpen: json['isEnabled'] == true || json['isOpen'] == true,
      remainingMale: _toIntOrNull(json['remainingMale']),
      remainingFemale: _toIntOrNull(json['remainingFemale']),
      remainingTotal: _toIntOrNull(json['remainingTotal']),
      arrivalTimes: stringListFrom(json['arrivalTimes']),
      cutoffAt: DateTime.tryParse(json['cutoffAt']?.toString() ?? ''),
      dressCode: json['dressCode']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      idRequired: json['idRequired'] == true,
      used: rawUsed is Map
          ? EventGuestListUsed.fromJson(Map<String, dynamic>.from(rawUsed))
          : null,
      fallbacks: rawFallbacks is List
          ? rawFallbacks
                .whereType<Map>()
                .map(
                  (row) => EventGuestListFallback.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .where((item) => item.id.isNotEmpty || item.label.isNotEmpty)
                .toList()
          : const [],
    );
  }

  static EventGuestListModel? tryFrom(dynamic value) {
    if (value is! Map) return null;
    return EventGuestListModel.fromJson(Map<String, dynamic>.from(value));
  }
}

class EventGuestListEntry {
  const EventGuestListEntry({
    this.id = '',
    this.name = '',
    this.email = '',
    this.phone = '',
    this.menCount = 0,
    this.womenCount = 0,
    this.otherCount = 0,
    this.arrivalTime = '',
    this.status = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final int menCount;
  final int womenCount;
  final int otherCount;
  final String arrivalTime;
  final String status;
  final DateTime? createdAt;

  factory EventGuestListEntry.fromJson(Map<String, dynamic> json) {
    return EventGuestListEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: (json['phone'] ?? json['phoneNumber'])?.toString() ?? '',
      menCount: _toInt(json['menCount']),
      womenCount: _toInt(json['womenCount']),
      otherCount: _toInt(json['otherCount'] ?? json['othersCount']),
      arrivalTime: json['arrivalTime']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class EventHostModel {
  const EventHostModel({
    this.id = '',
    this.name = '',
    this.role = '',
    this.isVerified = false,
    this.photo,
    this.whatsapp = '',
    this.phone = '',
    this.email = '',
    this.bio = '',
    this.officialPricesNote = '',
  });

  final String id;
  final String name;
  final String role;
  final bool isVerified;
  final String? photo;
  final String whatsapp;
  final String phone;
  final String email;
  final String bio;
  final String officialPricesNote;

  factory EventHostModel.fromJson(Map<String, dynamic> json) {
    final photo = json['photo']?.toString().trim();
    return EventHostModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      isVerified: json['isVerified'] == true,
      photo: photo == null || photo.isEmpty ? null : photo,
      whatsapp: json['whatsapp']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      officialPricesNote: json['officialPricesNote']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toPayload({bool includeId = false}) {
    return {
      if (includeId && id.trim().isNotEmpty) 'id': id.trim(),
      'name': name.trim(),
      if (role.trim().isNotEmpty) 'role': role.trim(),
      'isVerified': isVerified,
      if (photo != null && photo!.trim().isNotEmpty) 'photo': photo!.trim(),
      if (whatsapp.trim().isNotEmpty) 'whatsapp': whatsapp.trim(),
      if (phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (email.trim().isNotEmpty) 'email': email.trim(),
      if (bio.trim().isNotEmpty) 'bio': bio.trim(),
      if (officialPricesNote.trim().isNotEmpty)
        'officialPricesNote': officialPricesNote.trim(),
    };
  }

  static List<EventHostModel> listFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => EventHostModel.fromJson(Map<String, dynamic>.from(row)))
        .where((item) => item.id.isNotEmpty || item.name.isNotEmpty)
        .toList();
  }
}

class EventQuoteModel {
  const EventQuoteModel({
    this.id = '',
    this.eventId = '',
    this.moduleId = '',
    this.name = '',
    this.email = '',
    this.phone = '',
    this.guestCount = 0,
    this.status = '',
    this.message = '',
    this.createdAt,
    this.eventName = '',
    this.moduleName = '',
  });

  final String id;
  final String eventId;
  final String moduleId;
  final String name;
  final String email;
  final String phone;
  final int guestCount;
  final String status;
  final String message;
  final DateTime? createdAt;
  final String eventName;
  final String moduleName;

  EventQuoteModel copyWith({
    String? id,
    String? eventId,
    String? moduleId,
    String? name,
    String? email,
    String? phone,
    int? guestCount,
    String? status,
    String? message,
    DateTime? createdAt,
    String? eventName,
    String? moduleName,
  }) {
    return EventQuoteModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      moduleId: moduleId ?? this.moduleId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      guestCount: guestCount ?? this.guestCount,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      eventName: eventName ?? this.eventName,
      moduleName: moduleName ?? this.moduleName,
    );
  }

  factory EventQuoteModel.fromJson(Map<String, dynamic> json) {
    final eventObj = json['event'] is Map ? json['event'] as Map : null;
    final moduleObj = (json['module'] ?? json['vipModule']) is Map
        ? (json['module'] ?? json['vipModule']) as Map
        : null;

    final parsedEventName = (json['eventName'] ??
            json['eventTitle'] ??
            eventObj?['name'] ??
            eventObj?['title'] ??
            eventObj?['eventName'])
        ?.toString() ??
        '';

    final parsedModuleName = (json['moduleName'] ??
            json['tableName'] ??
            moduleObj?['name'] ??
            moduleObj?['title'])
        ?.toString() ??
        '';

    return EventQuoteModel(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      moduleId: json['moduleId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: (json['phone'] ?? json['phoneNumber'])?.toString() ?? '',
      guestCount: _toInt(json['guestCount']),
      status: json['status']?.toString() ?? '',
      message: (json['message'] ?? json['Message'])?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      eventName: parsedEventName,
      moduleName: parsedModuleName,
    );
  }

  static List<EventQuoteModel> listFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => EventQuoteModel.fromJson(Map<String, dynamic>.from(row)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }
}

class EventHostInquiryModel {
  const EventHostInquiryModel({
    this.id = '',
    this.hostId = '',
    this.hostName = '',
    this.customerName = '',
    this.customerEmail = '',
    this.customerPhone = '',
    this.message = '',
    this.createdAt,
    this.eventId = '',
  });

  final String id;
  final String hostId;
  final String hostName;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String message;
  final DateTime? createdAt;
  final String eventId;

  factory EventHostInquiryModel.fromJson(Map<String, dynamic> json) {
    final hostObj = json['host'] is Map ? json['host'] as Map : null;
    return EventHostInquiryModel(
      id: json['id']?.toString() ?? '',
      hostId: (json['hostId'] ?? hostObj?['id'])?.toString() ?? '',
      hostName: (json['hostName'] ?? hostObj?['name'])?.toString() ?? '',
      customerName: (json['customerName'] ?? json['name'])?.toString() ?? '',
      customerEmail: (json['customerEmail'] ?? json['email'])?.toString() ?? '',
      customerPhone:
          (json['customerPhone'] ?? json['phone'] ?? json['phoneNumber'])
              ?.toString() ??
          '',
      message: (json['message'] ?? json['Message'])?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      eventId: json['eventId']?.toString() ?? '',
    );
  }

  static List<EventHostInquiryModel> listFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) =>
            EventHostInquiryModel.fromJson(Map<String, dynamic>.from(row)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }
}

class FollowedArtistModel {
  const FollowedArtistModel({
    this.id = '',
    this.name = '',
    this.avatar,
    this.followerCount = 0,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String? avatar;
  final int followerCount;
  final bool isVerified;

  factory FollowedArtistModel.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar']?.toString().trim();
    return FollowedArtistModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: avatar == null || avatar.isEmpty ? null : avatar,
      followerCount: _toInt(json['followerCount']),
      isVerified: json['isVerified'] == true,
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
