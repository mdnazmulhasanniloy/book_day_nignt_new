class ClubModel {
  final String id;
  final String image, title, location, rating, price, type;
  final List<String>? tags;
  final DateTime? availableDate;
  final DateTime? startAt;
  final DateTime? endAt;
  final double? latitude;
  final double? longitude;
  final bool isWishlist;
  final bool isVip;

  ClubModel({
    this.id = '',
    required this.image,
    required this.title,
    required this.location,
    required this.rating,
    required this.price,
    required this.type,
    this.tags,
    this.availableDate,
    this.startAt,
    this.endAt,
    this.latitude,
    this.longitude,
    this.isWishlist = false,
    this.isVip = false,
  });

  bool get isEvent => type.toLowerCase() == 'event';
  bool get hasRating => rating.trim().isNotEmpty;

  String get wishlistKey => '${type.toUpperCase()}_$id';

  ClubModel copyWith({
    String? id,
    String? image,
    String? title,
    String? location,
    String? rating,
    String? price,
    String? type,
    List<String>? tags,
    DateTime? availableDate,
    DateTime? startAt,
    DateTime? endAt,
    double? latitude,
    double? longitude,
    bool? isWishlist,
    bool? isVip,
  }) {
    return ClubModel(
      id: id ?? this.id,
      image: image ?? this.image,
      title: title ?? this.title,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      availableDate: availableDate ?? this.availableDate,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isWishlist: isWishlist ?? this.isWishlist,
      isVip: isVip ?? this.isVip,
    );
  }
}
