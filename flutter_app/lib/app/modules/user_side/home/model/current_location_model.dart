enum LocationAccessStatus {
  available,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class CurrentLocationModel {
  final double? latitude;
  final double? longitude;
  final String address;
  final LocationAccessStatus status;

  const CurrentLocationModel({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.status,
  });

  const CurrentLocationModel.serviceDisabled()
    : latitude = null,
      longitude = null,
      address = '',
      status = LocationAccessStatus.serviceDisabled;

  const CurrentLocationModel.permissionDenied()
    : latitude = null,
      longitude = null,
      address = '',
      status = LocationAccessStatus.permissionDenied;

  const CurrentLocationModel.permissionDeniedForever()
    : latitude = null,
      longitude = null,
      address = '',
      status = LocationAccessStatus.permissionDeniedForever;

  const CurrentLocationModel.unavailable()
    : latitude = null,
      longitude = null,
      address = '',
      status = LocationAccessStatus.unavailable;

  bool get isAvailable =>
      status == LocationAccessStatus.available &&
      latitude != null &&
      longitude != null;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status.name,
    };
  }

  factory CurrentLocationModel.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString();
    final status = LocationAccessStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => LocationAccessStatus.unavailable,
    );

    return CurrentLocationModel(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address']?.toString() ?? '',
      status: status,
    );
  }
}
