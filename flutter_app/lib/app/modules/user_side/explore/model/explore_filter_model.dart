class ExploreFilterModel {
  final String category;
  final DateTime? date;
  final String? location;
  final double? latitude;
  final double? longitude;
  final double radiusInKm;
  final double? minimumPrice;
  final double? maximumPrice;
  final double? minimumRating;
  final double? maximumRating;

  const ExploreFilterModel({
    this.category = 'All',
    this.date,
    this.location,
    this.latitude,
    this.longitude,
    this.radiusInKm = 30,
    this.minimumPrice,
    this.maximumPrice,
    this.minimumRating,
    this.maximumRating,
  });
}
