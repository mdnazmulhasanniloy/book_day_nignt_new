import 'dart:io';

import 'package:bookdianight_app/app/core/utils/cst_time.dart';

class ClubOpeningHourModel {
  final String? id;
  final int dayOfWeek;
  final bool isClosed;
  final DateTime openTime;
  final DateTime closeTime;
  final bool closesNextDay;

  const ClubOpeningHourModel({
    this.id,
    required this.dayOfWeek,
    required this.isClosed,
    required this.openTime,
    required this.closeTime,
    required this.closesNextDay,
  });

  Map<String, dynamic> toJson({required bool includeUpdateFields}) {
    return {
      'dayOfWeek': dayOfWeek,
      'isClosed': isClosed,
      'openTime': clubClockIso(openTime),
      'closeTime': clubClockIso(closeTime),
      'closesNextDay': closesNextDay,
      if (includeUpdateFields && id != null) 'id': id,
    };
  }
}

class ClubPackageModel {
  final String? id;
  final String name;
  final String description;
  final int capacity;
  final double price;
  final String currency;
  final List<String> features;
  final int sortOrder;
  final bool isActive;

  const ClubPackageModel({
    this.id,
    required this.name,
    required this.description,
    required this.capacity,
    required this.price,
    required this.currency,
    required this.features,
    required this.sortOrder,
    this.isActive = true,
  });

  ClubPackageModel copyWith({
    String? name,
    String? description,
    int? capacity,
    double? price,
    String? currency,
    List<String>? features,
    int? sortOrder,
    bool? isActive,
  }) {
    return ClubPackageModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      capacity: capacity ?? this.capacity,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      features: features ?? this.features,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson({required bool includeUpdateFields}) {
    return {
      'name': name,
      'description': description,
      'capacity': capacity,
      'price': price,
      'currency': 'EUR',
      'features': features,
      'sortOrder': sortOrder,
      if (includeUpdateFields && id != null) 'id': id,
      if (includeUpdateFields) 'isActive': isActive,
    };
  }
}

class ClubDraftModel {
  final String? clubId;
  final String name;
  final String description;
  final String location;
  final String dressCode;
  final bool isRecurring;
  final bool isVip;
  final double latitude;
  final double longitude;
  final List<ClubOpeningHourModel> openingHours;
  final bool isActive;
  final File? thumbnailFile;
  final List<File> galleryFiles;
  final String existingThumbnail;
  final List<String> existingImages;
  final List<ClubPackageModel> existingPackages;

  const ClubDraftModel({
    this.clubId,
    required this.name,
    required this.description,
    required this.location,
    required this.dressCode,
    required this.isRecurring,
    required this.isVip,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    this.isActive = true,
    this.thumbnailFile,
    this.galleryFiles = const [],
    this.existingThumbnail = '',
    this.existingImages = const [],
    this.existingPackages = const [],
  });

  bool get isEditing => clubId != null && clubId!.isNotEmpty;
}

class ClubUpsertRequestModel {
  final String name;
  final String description;
  final String location;
  final String thumbnail;
  final List<String> images;
  final String dressCode;
  final bool isRecurring;
  final bool isVip;
  final double latitude;
  final double longitude;
  final List<ClubOpeningHourModel> openingHours;
  final List<ClubPackageModel> packages;
  final bool isActive;

  const ClubUpsertRequestModel({
    required this.name,
    required this.description,
    required this.location,
    required this.thumbnail,
    required this.images,
    required this.dressCode,
    required this.isRecurring,
    required this.isVip,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    required this.packages,
    this.isActive = true,
  });

  Map<String, dynamic> toJson({required bool isUpdate}) {
    return {
      'name': name,
      'description': description,
      'location': location,
      'thumbnail': thumbnail,
      'images': images,
      'dressCode': dressCode,
      'isRecurring': isRecurring,
      'isVip': isVip,
      'lat': latitude,
      'lng': longitude,
      if (isUpdate) 'isActive': isActive,
      'openingHours': openingHours
          .map((hours) => hours.toJson(includeUpdateFields: isUpdate))
          .toList(growable: false),
      'packages': packages
          .map((package) => package.toJson(includeUpdateFields: isUpdate))
          .toList(growable: false),
    };
  }
}

class ClubMutationResponseModel {
  final bool success;
  final String message;
  final String? clubId;
  final bool? isActive;
  final DateTime? deactivatedAt;

  const ClubMutationResponseModel({
    required this.success,
    required this.message,
    this.clubId,
    this.isActive,
    this.deactivatedAt,
  });

  factory ClubMutationResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;
    final club = dataMap?['club'];
    final clubMap = club is Map ? Map<String, dynamic>.from(club) : null;
    final source = clubMap ?? dataMap;
    final deactivatedRaw = source?['deactivatedAt']?.toString();
    final deactivatedAt = deactivatedRaw == null || deactivatedRaw.isEmpty
        ? null
        : DateTime.tryParse(deactivatedRaw);
    bool? isActive;
    if (source?['isActive'] is bool) {
      isActive = source!['isActive'] as bool;
    } else if (source != null && source.containsKey('deactivatedAt')) {
      isActive = deactivatedAt == null;
    }
    return ClubMutationResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      clubId: (dataMap?['id'] ?? clubMap?['id'])?.toString(),
      isActive: isActive,
      deactivatedAt: deactivatedAt,
    );
  }
}
