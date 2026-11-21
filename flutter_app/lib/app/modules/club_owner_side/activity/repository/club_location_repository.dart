import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';

import '../../../../config/flavor_config.dart';
import '../model/club_location_model.dart';

class ClubLocationRepository {
  ClubLocationRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<List<ClubPlaceSuggestionModel>> searchSuggestions({
    required String query,
    double? latitude,
    double? longitude,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) return const [];

    final body = <String, dynamic>{
      'input': normalizedQuery,
      'languageCode': 'en',
    };
    if (latitude != null && longitude != null) {
      body['locationBias'] = {
        'circle': {
          'center': {'latitude': latitude, 'longitude': longitude},
          'radius': 50000.0,
        },
      };
    }

    final response = await _dio.post<Map<String, dynamic>>(
      'https://places.googleapis.com/v1/places:autocomplete',
      data: body,
      options: Options(
        headers: {
          'X-Goog-Api-Key': AppConfig.googleMapsKey,
          'X-Goog-FieldMask':
              'suggestions.placePrediction.placeId,'
              'suggestions.placePrediction.text,'
              'suggestions.placePrediction.structuredFormat',
        },
      ),
    );

    final suggestions = response.data?['suggestions'] as List<dynamic>? ?? [];
    return suggestions
        .map((item) {
          final prediction =
              (item as Map<String, dynamic>)['placePrediction']
                  as Map<String, dynamic>?;
          final structured =
              prediction?['structuredFormat'] as Map<String, dynamic>?;
          final mainText = structured?['mainText'] as Map<String, dynamic>?;
          final secondaryText =
              structured?['secondaryText'] as Map<String, dynamic>?;
          final fullText = prediction?['text'] as Map<String, dynamic>?;

          return ClubPlaceSuggestionModel(
            placeId: prediction?['placeId']?.toString(),
            primaryText:
                mainText?['text']?.toString() ??
                fullText?['text']?.toString() ??
                '',
            secondaryText: secondaryText?['text']?.toString() ?? '',
          );
        })
        .where((item) => item.primaryText.isNotEmpty)
        .take(6)
        .toList(growable: false);
  }

  Future<ClubPlaceSuggestionModel> resolveSuggestion(
    ClubPlaceSuggestionModel suggestion,
  ) async {
    if (suggestion.hasCoordinates || suggestion.placeId == null) {
      return suggestion;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      'https://places.googleapis.com/v1/places/${suggestion.placeId}',
      options: Options(
        headers: {
          'X-Goog-Api-Key': AppConfig.googleMapsKey,
          'X-Goog-FieldMask': 'displayName,formattedAddress,location',
        },
      ),
    );
    final data = response.data ?? const <String, dynamic>{};
    final displayName = data['displayName'] as Map<String, dynamic>?;
    final location = data['location'] as Map<String, dynamic>?;

    return suggestion.copyWith(
      primaryText: displayName?['text']?.toString() ?? suggestion.primaryText,
      secondaryText:
          data['formattedAddress']?.toString() ?? suggestion.secondaryText,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
    );
  }

  Future<ClubLocationSelectionModel> resolveAddress(String address) async {
    final results = await locationFromAddress(address.trim());
    if (results.isEmpty) throw StateError('Location not found');
    return ClubLocationSelectionModel(
      address: address.trim(),
      latitude: results.first.latitude,
      longitude: results.first.longitude,
    );
  }

  Future<String> addressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) return _coordinateLabel(latitude, longitude);

    final place = placemarks.first;
    final parts = <String?>[
      place.name,
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ];
    final uniqueParts = <String>[];
    for (final part in parts) {
      final value = part?.trim() ?? '';
      if (value.isNotEmpty && !uniqueParts.contains(value)) {
        uniqueParts.add(value);
      }
    }
    return uniqueParts.isEmpty
        ? _coordinateLabel(latitude, longitude)
        : uniqueParts.join(', ');
  }

  String _coordinateLabel(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}
