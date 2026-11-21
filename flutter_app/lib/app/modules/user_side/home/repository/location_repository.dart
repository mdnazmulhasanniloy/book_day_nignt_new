import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../model/current_location_model.dart';

class LocationRepository {
  Future<CurrentLocationModel> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const CurrentLocationModel.serviceDisabled();
      }

      final permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        return const CurrentLocationModel.permissionDenied();
      }
      if (permission == LocationPermission.deniedForever) {
        return const CurrentLocationModel.permissionDeniedForever();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final address = await _getAddress(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      return CurrentLocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        status: LocationAccessStatus.available,
      );
    } catch (_) {
      return const CurrentLocationModel.unavailable();
    }
  }

  Future<String> _getAddress({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts =
            <String?>[
                  place.street,
                  place.subLocality,
                  place.locality,
                  place.administrativeArea,
                  place.country,
                ]
                .whereType<String>()
                .map((part) => part.trim())
                .where((part) => part.isNotEmpty)
                .toSet();

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {
      // Coordinates remain usable if reverse geocoding is unavailable.
    }

    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}
