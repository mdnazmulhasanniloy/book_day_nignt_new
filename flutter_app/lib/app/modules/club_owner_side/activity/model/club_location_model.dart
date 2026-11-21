class ClubPlaceSuggestionModel {
  const ClubPlaceSuggestionModel({
    this.placeId,
    required this.primaryText,
    this.secondaryText = '',
    this.latitude,
    this.longitude,
  });

  final String? placeId;
  final String primaryText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  String get displayText =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';

  bool get hasCoordinates => latitude != null && longitude != null;

  ClubPlaceSuggestionModel copyWith({
    String? primaryText,
    String? secondaryText,
    double? latitude,
    double? longitude,
  }) {
    return ClubPlaceSuggestionModel(
      placeId: placeId,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class ClubLocationSelectionModel {
  const ClubLocationSelectionModel({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;
}
