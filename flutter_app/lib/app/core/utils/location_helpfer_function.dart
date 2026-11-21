import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationHelperFunction {
  static final Map<String, Future<Placemark?>> _placemarkCache = {};

  static Future<String> getAddressFromLatLng({
    required double lat,
    required double lng,
    String fallback = 'Location unavailable',
  }) {
    return getFullAddressFromLatLng(lat: lat, lng: lng, fallback: fallback);
  }

  static Future<String> getCityCountryFromLatLng({
    required double lat,
    required double lng,
    String fallback = '',
  }) async {
    if (!_isValidCoordinate(lat, lng)) return fallback;
    final place = await _getPlacemark(lat, lng);
    if (place == null) return fallback;

    final city = _firstAvailable([
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]);
    return _joinUnique([city, place.country], fallback: fallback);
  }

  static Future<String> getFullAddressFromLatLng({
    required double lat,
    required double lng,
    String fallback = '',
  }) async {
    if (!_isValidCoordinate(lat, lng)) return fallback;
    final place = await _getPlacemark(lat, lng);
    if (place == null) return fallback;

    return _joinUnique([
      place.street,
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ], fallback: fallback);
  }

  static Future<Placemark?> _getPlacemark(double lat, double lng) {
    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    return _placemarkCache.putIfAbsent(key, () => _resolvePlacemark(lat, lng));
  }

  static Future<Placemark?> _resolvePlacemark(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) return placemarks.first;
    } catch (_) {
      // The caller-provided text is used when reverse geocoding is unavailable.
    }
    return null;
  }

  static String? _firstAvailable(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  static String _joinUnique(List<String?> values, {required String fallback}) {
    final parts = <String>[];
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty &&
          !parts.any(
            (part) => part.toLowerCase() == normalized.toLowerCase(),
          )) {
        parts.add(normalized);
      }
    }
    return parts.isEmpty ? fallback : parts.join(', ');
  }

  static bool _isValidCoordinate(double lat, double lng) =>
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      (lat != 0 || lng != 0);

  static Future<String> getCurrentAreaName() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return "Location Off";
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          return "Permission Denied";
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return "Permission Denied Forever";
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        return place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            "Unknown Location";
      }

      ///if need with country
      /*if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        final locality = place.locality;
        final country = place.country;

        return [
          locality,
          country,
        ]
            .where((e) => e != null && e.isNotEmpty)
            .join(', ');
      }*/

      return "Unknown Location";
    } catch (e) {
      return "Location Unavailable";
    }
  }
}
