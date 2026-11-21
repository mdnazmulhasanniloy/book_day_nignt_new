import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../../config/flavor_config.dart';
import '../../home/controllers/club_controller.dart';
import '../model/explore_filter_model.dart';
import '../model/place_suggestion_model.dart';

class ExploreRepository {
  ExploreRepository(this._clubController, {Dio? dio}) : _dio = dio ?? Dio();

  final ClubController _clubController;
  final Dio _dio;

  static const popularCities = <PlaceSuggestionModel>[
    PlaceSuggestionModel(
      primaryText: 'London',
      secondaryText: 'United Kingdom',
      latitude: 51.5072,
      longitude: -0.1276,
    ),
    PlaceSuggestionModel(
      primaryText: 'Paris',
      secondaryText: 'France',
      latitude: 48.8566,
      longitude: 2.3522,
    ),
    PlaceSuggestionModel(
      primaryText: 'Rome',
      secondaryText: 'Italy',
      latitude: 41.9028,
      longitude: 12.4964,
    ),
    PlaceSuggestionModel(
      primaryText: 'Milan',
      secondaryText: 'Italy',
      latitude: 45.4642,
      longitude: 9.1900,
    ),
    PlaceSuggestionModel(
      primaryText: 'Florence',
      secondaryText: 'Italy',
      latitude: 43.7696,
      longitude: 11.2558,
    ),
    PlaceSuggestionModel(
      primaryText: 'Venice',
      secondaryText: 'Italy',
      latitude: 45.4408,
      longitude: 12.3155,
    ),
    PlaceSuggestionModel(
      primaryText: 'Barcelona',
      secondaryText: 'Spain',
      latitude: 41.3874,
      longitude: 2.1686,
    ),
    PlaceSuggestionModel(
      primaryText: 'Amsterdam',
      secondaryText: 'Netherlands',
      latitude: 52.3676,
      longitude: 4.9041,
    ),
    PlaceSuggestionModel(
      primaryText: 'Berlin',
      secondaryText: 'Germany',
      latitude: 52.5200,
      longitude: 13.4050,
    ),
    PlaceSuggestionModel(
      primaryText: 'Madrid',
      secondaryText: 'Spain',
      latitude: 40.4168,
      longitude: -3.7038,
    ),
    PlaceSuggestionModel(
      primaryText: 'Vienna',
      secondaryText: 'Austria',
      latitude: 48.2082,
      longitude: 16.3738,
    ),
    PlaceSuggestionModel(
      primaryText: 'Prague',
      secondaryText: 'Czech Republic',
      latitude: 50.0755,
      longitude: 14.4378,
    ),
    PlaceSuggestionModel(
      primaryText: 'Lisbon',
      secondaryText: 'Portugal',
      latitude: 38.7223,
      longitude: -9.1393,
    ),
    PlaceSuggestionModel(
      primaryText: 'Athens',
      secondaryText: 'Greece',
      latitude: 37.9838,
      longitude: 23.7275,
    ),
    PlaceSuggestionModel(
      primaryText: 'Zurich',
      secondaryText: 'Switzerland',
      latitude: 47.3769,
      longitude: 8.5417,
    ),
    PlaceSuggestionModel(
      primaryText: 'New York',
      secondaryText: 'United States',
      latitude: 40.7128,
      longitude: -74.0060,
    ),
    PlaceSuggestionModel(
      primaryText: 'Dubai',
      secondaryText: 'United Arab Emirates',
      latitude: 25.2048,
      longitude: 55.2708,
    ),
    PlaceSuggestionModel(
      primaryText: 'Tokyo',
      secondaryText: 'Japan',
      latitude: 35.6762,
      longitude: 139.6503,
    ),
  ];

  List<ClubModel> getVenues() {
    final venues = <ClubModel>[
      ..._clubController.tonightClubs,
      ..._clubController.popularClubs,
    ];
    final uniqueVenues = <String, ClubModel>{};

    for (final venue in venues) {
      final key = '${venue.title}|${venue.location}'.toLowerCase();
      uniqueVenues[key] = venue;
    }

    return uniqueVenues.values.toList(growable: false);
  }

  List<ClubModel> filterVenues({
    required String query,
    required ExploreFilterModel filter,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    return getVenues()
        .where((venue) {
          final searchableText = [
            venue.title,
            venue.location,
            venue.type,
            ...?venue.tags,
          ].join(' ').toLowerCase();
          final matchesQuery =
              normalizedQuery.isEmpty ||
              searchableText.contains(normalizedQuery);
          final matchesCategory =
              filter.category == 'All' ||
              venue.type.toLowerCase() == filter.category.toLowerCase();
          final matchesLocation =
              filter.latitude != null && filter.longitude != null
              ? venue.latitude != null &&
                    venue.longitude != null &&
                    _distanceInKm(
                          filter.latitude!,
                          filter.longitude!,
                          venue.latitude!,
                          venue.longitude!,
                        ) <=
                        filter.radiusInKm
              : filter.location == null ||
                    venue.location.toLowerCase() ==
                        filter.location!.toLowerCase();
          final matchesDate =
              filter.date == null ||
              (venue.availableDate != null &&
                  _isSameDay(venue.availableDate!, filter.date!));

          final price = _numberFrom(venue.price);
          final matchesMinimumPrice =
              filter.minimumPrice == null || price >= filter.minimumPrice!;
          final matchesMaximumPrice =
              filter.maximumPrice == null || price <= filter.maximumPrice!;

          final rating = double.tryParse(venue.rating) ?? 0;
          final matchesRating =
              (filter.minimumRating == null ||
                  rating >= filter.minimumRating!) &&
              (filter.maximumRating == null || rating < filter.maximumRating!);

          return matchesQuery &&
              matchesCategory &&
              matchesLocation &&
              matchesDate &&
              matchesMinimumPrice &&
              matchesMaximumPrice &&
              matchesRating;
        })
        .toList(growable: false);
  }

  double _numberFrom(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  List<PlaceSuggestionModel> localPlaceSuggestions(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) return const [];

    final unique = <String, PlaceSuggestionModel>{};
    for (final city in popularCities) {
      final searchableText = '${city.primaryText} ${city.secondaryText}'
          .toLowerCase();
      if (searchableText.contains(normalizedQuery)) {
        unique[city.displayText.toLowerCase()] = city;
      }
    }
    for (final venue in getVenues()) {
      if (!venue.location.toLowerCase().contains(normalizedQuery)) continue;
      unique[venue.location.toLowerCase()] = PlaceSuggestionModel(
        primaryText: venue.location,
        secondaryText: 'Venue location',
        latitude: venue.latitude,
        longitude: venue.longitude,
        venueLocation: venue.location,
      );
    }
    return unique.values.toList(growable: false);
  }

  Future<List<PlaceSuggestionModel>> searchPlaceSuggestions({
    required String query,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{'input': query.trim(), 'languageCode': 'en'};
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

          return PlaceSuggestionModel(
            placeId: prediction?['placeId']?.toString(),
            primaryText:
                mainText?['text']?.toString() ??
                fullText?['text']?.toString() ??
                '',
            secondaryText: secondaryText?['text']?.toString() ?? '',
          );
        })
        .where((item) => item.primaryText.isNotEmpty)
        .toList(growable: false);
  }

  Future<PlaceSuggestionModel> resolvePlace(
    PlaceSuggestionModel suggestion,
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

  double _distanceInKm(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadius = 6371.0;
    final latitudeDistance = _toRadians(secondLatitude - firstLatitude);
    final longitudeDistance = _toRadians(secondLongitude - firstLongitude);
    final value =
        math.sin(latitudeDistance / 2) * math.sin(latitudeDistance / 2) +
        math.cos(_toRadians(firstLatitude)) *
            math.cos(_toRadians(secondLatitude)) *
            math.sin(longitudeDistance / 2) *
            math.sin(longitudeDistance / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }

  double _toRadians(double degree) => degree * math.pi / 180;
}
