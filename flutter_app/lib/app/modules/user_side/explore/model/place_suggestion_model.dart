class PlaceSuggestionModel {
  final String? placeId;
  final String primaryText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;
  final String? venueLocation;

  const PlaceSuggestionModel({
    this.placeId,
    required this.primaryText,
    this.secondaryText = '',
    this.latitude,
    this.longitude,
    this.venueLocation,
  });

  String get displayText =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';

  bool get hasCoordinates => latitude != null && longitude != null;

  PlaceSuggestionModel copyWith({
    String? primaryText,
    String? secondaryText,
    double? latitude,
    double? longitude,
  }) {
    return PlaceSuggestionModel(
      placeId: placeId,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      venueLocation: venueLocation,
    );
  }
}
