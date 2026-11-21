import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/explore/model/explore_api_model.dart';
import '../../../../core/explore/model/explore_item_mapper.dart';
import '../../../../core/explore/repository/explore_api_repository.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../home/controllers/club_controller.dart';
import '../../home/controllers/user_location_controller.dart';
import '../../home/model/current_location_model.dart';
import '../../favorite/controllers/wishlist_controller.dart';
import '../model/place_suggestion_model.dart';
import '../repository/explore_repository.dart';

class ExploreController extends GetxController {
  ExploreController({
    ExploreApiRepository? apiRepository,
    ExploreRepository? placesRepository,
  }) : _apiRepository = apiRepository ?? ExploreApiRepository(),
       _placesRepository =
           placesRepository ??
           ExploreRepository(
             Get.isRegistered<ClubController>()
                 ? Get.find<ClubController>()
                 : Get.put(ClubController()),
           );

  final ExploreApiRepository _apiRepository;
  final ExploreRepository _placesRepository;

  static const int pageLimit = 10;

  final selectedTab = 'Date'.obs;
  final selectedCategory = 'All'.obs;
  final selectedCategoryType = 'All'.obs;
  final selectedDateOption = 'Any date'.obs;
  final selectedLocation = 'Any location'.obs;
  final selectedPriceRange = 'Any price'.obs;
  final selectedRating = 'Any rating'.obs;
  final selectedMood = ''.obs;
  final locationQuery = ''.obs;
  final searchQuery = ''.obs;
  final filteredVenues = <ClubModel>[].obs;
  final currentLocation = Rxn<CurrentLocationModel>();
  final isLocationLoading = false.obs;
  final placeSuggestions = <PlaceSuggestionModel>[].obs;
  final selectedPlace = Rxn<PlaceSuggestionModel>();
  final isSearchingPlaces = false.obs;
  final isResolvingPlace = false.obs;

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final totalVenues = 0.obs;

  int _currentPage = 0;
  Timer? _placeSearchDebounce;
  Timer? _searchDebounce;

  final searchController = TextEditingController();
  final searchFocus = FocusNode();
  final locationSearchController = TextEditingController();
  final customDateController = TextEditingController();
  final moodController = TextEditingController();
  final minimumPriceController = TextEditingController();
  final maximumPriceController = TextEditingController();

  static const categories = ['All', 'Club', 'Event'];
  static const categoryTypes = [
    'All',
    'Club',
    'Concert',
    'Festival',
    'Open air',
    'Warehouse',
  ];
  static const dateOptions = [
    'Any date',
    'Today',
    'Tomorrow',
    'This weekend',
    'Next weekend',
  ];
  static const priceOptions = [
    'Free',
    'Max €15',
    'Under €20',
    '€25 to €100',
    '€100 to €300',
    '€300 to €500',
  ];
  static const ratingOptions = ['Any rating', '4.5+', '4.00 - 4.5', '3.5 - 4.00'];

  @override
  void onInit() {
    super.onInit();
    placeSuggestions.assignAll(ExploreRepository.popularCities);
    fetchVenues(refresh: true);
    _loadCurrentLocation();
  }

  String get currentLocationLabel {
    if (isLocationLoading.value) return 'Getting your current location...';
    final location = currentLocation.value;
    if (location?.isAvailable == true && location!.address.isNotEmpty) {
      return location.address;
    }

    switch (location?.status) {
      case LocationAccessStatus.serviceDisabled:
        return 'Turn on location services';
      case LocationAccessStatus.permissionDenied:
        return 'Location permission was denied';
      case LocationAccessStatus.permissionDeniedForever:
        return 'Allow location from device settings';
      default:
        return 'Current location unavailable';
    }
  }

  void dismissSearchFocus() {
    searchFocus.unfocus();
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => fetchVenues(refresh: true),
    );
  }

  void onLocationSearchChanged(String value) {
    locationQuery.value = value;
    final activePlace = selectedPlace.value;
    if (activePlace != null && value.trim() != activePlace.displayText) {
      selectedPlace.value = null;
      selectedLocation.value = 'Any location';
    }
    _placeSearchDebounce?.cancel();
    if (value.trim().length < 2) {
      placeSuggestions.assignAll(ExploreRepository.popularCities);
      isSearchingPlaces.value = false;
      return;
    }

    _placeSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchPlaces(value),
    );
  }

  void selectLocation(String value) {
    selectedLocation.value = value;
    selectedPlace.value = null;
    placeSuggestions.assignAll(ExploreRepository.popularCities);
    locationQuery.value = '';
    locationSearchController.clear();
  }

  void selectPriceRange(String value) {
    selectedPriceRange.value = value;
    minimumPriceController.clear();
    maximumPriceController.clear();
  }

  void onCustomPriceChanged(String _) {
    final hasCustomPrice =
        minimumPriceController.text.trim().isNotEmpty ||
        maximumPriceController.text.trim().isNotEmpty;
    selectedPriceRange.value = hasCustomPrice ? 'Custom price' : 'Any price';
  }

  Future<void> selectPlace(PlaceSuggestionModel suggestion) async {
    isResolvingPlace.value = true;
    try {
      final resolved = await _placesRepository.resolvePlace(suggestion);
      selectedPlace.value = resolved;
      selectedLocation.value = resolved.displayText;
      locationSearchController.text = resolved.displayText;
      locationQuery.value = resolved.displayText;
      placeSuggestions.clear();
    } catch (_) {
      selectedPlace.value = suggestion;
      selectedLocation.value = suggestion.displayText;
      locationSearchController.text = suggestion.displayText;
      locationQuery.value = suggestion.displayText;
      placeSuggestions.clear();
    } finally {
      isResolvingPlace.value = false;
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _customDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      customDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      selectedDateOption.value = 'Custom date';
    }
  }

  Future<void> applyFilters() => fetchVenues(refresh: true);

  Future<void> fetchVenues({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      hasMore.value = true;
    }

    if (!hasMore.value && !refresh) return;
    if (isLoading.value || isLoadingMore.value) return;

    if (refresh || filteredVenues.isEmpty) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    final nextPage = _currentPage + 1;

    try {
      final response = await _apiRepository.getExplore(_buildQuery(nextPage));
      final items = await withEventSchedules(
        response.data.map((item) => item.toClubModel()).toList(),
      );

      if (refresh || nextPage == 1) {
        filteredVenues.assignAll(items);
      } else {
        filteredVenues.addAll(items);
      }

      if (Get.isRegistered<WishlistController>()) {
        Get.find<WishlistController>().syncFromList(items);
      }

      _currentPage = nextPage;
      totalVenues.value = response.meta.total;
      hasMore.value = nextPage < response.meta.totalPages;
    } catch (e) {
      debugPrint('Explore fetch error: $e');
      if (refresh || filteredVenues.isEmpty) {
        CustomSnackBar.error(message: 'Failed to load venues');
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() => fetchVenues(refresh: false);

  ExploreQueryModel _buildQuery(int page) {
    final price = _priceBounds(selectedPriceRange.value);
    final rating = _ratingMinimum(selectedRating.value);
    final useCurrentLocation = selectedLocation.value == 'Current location';
    final place = selectedPlace.value;
    final category = selectedCategory.value;

    return ExploreQueryModel(
      type: category == 'All' ? null : category.toUpperCase(),
      categoryType: _categoryTypeParam,
      date: _selectedDate,
      dateFilter: _dateFilter,
      latitude: useCurrentLocation
          ? currentLocation.value?.latitude
          : place?.latitude,
      longitude: useCurrentLocation
          ? currentLocation.value?.longitude
          : place?.longitude,
      minimumPrice: price.$1,
      maximumPrice: price.$2,
      isFree: selectedPriceRange.value == 'Free',
      ratings: rating,
      search: searchQuery.value.trim().isEmpty ? null : searchQuery.value.trim(),
      city: _selectedCity,
      mood: selectedMood.value.trim().isEmpty ? null : selectedMood.value.trim(),
      page: page,
      limit: pageLimit,
    );
  }

  void resetFilters() {
    selectedCategory.value = 'All';
    selectedCategoryType.value = 'All';
    selectedDateOption.value = 'Any date';
    selectedLocation.value = 'Any location';
    selectedPriceRange.value = 'Any price';
    selectedRating.value = 'Any rating';
    selectedMood.value = '';
    moodController.clear();
    locationQuery.value = '';
    selectedPlace.value = null;
    placeSuggestions.assignAll(ExploreRepository.popularCities);
    locationSearchController.clear();
    customDateController.clear();
    minimumPriceController.clear();
    maximumPriceController.clear();
    fetchVenues(refresh: true);
  }

  Future<void> refreshCurrentLocation() => _loadCurrentLocation(force: true);

  Future<void> _searchPlaces(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery != locationQuery.value.trim()) return;

    isSearchingPlaces.value = true;
    final localSuggestions = _placesRepository.localPlaceSuggestions(
      normalizedQuery,
    );
    List<PlaceSuggestionModel> remoteSuggestions = const [];
    try {
      remoteSuggestions = await _placesRepository.searchPlaceSuggestions(
        query: normalizedQuery,
        latitude: currentLocation.value?.latitude,
        longitude: currentLocation.value?.longitude,
      );
    } catch (_) {
      // Local venue suggestions remain available if Places is unavailable.
    }

    if (normalizedQuery != locationQuery.value.trim()) return;
    final unique = <String, PlaceSuggestionModel>{};
    for (final suggestion in [...localSuggestions, ...remoteSuggestions]) {
      unique.putIfAbsent(
        suggestion.displayText.toLowerCase(),
        () => suggestion,
      );
    }
    placeSuggestions.assignAll(unique.values.take(8));
    isSearchingPlaces.value = false;
  }

  Future<void> _loadCurrentLocation({bool force = false}) async {
    final locationController = Get.isRegistered<UserLocationController>()
        ? Get.find<UserLocationController>()
        : Get.put(UserLocationController());

    final existingLocation = locationController.currentLocation.value;
    if (!force && existingLocation != null) {
      currentLocation.value = existingLocation;
      if (existingLocation.isAvailable) return;
    }

    isLocationLoading.value = true;
    currentLocation.value = await locationController.loadCurrentLocation();
    isLocationLoading.value = false;
  }

  String? get _dateFilter {
    switch (selectedDateOption.value) {
      case 'Today':
        return 'today';
      case 'Tomorrow':
        return 'tomorrow';
      case 'This weekend':
        return 'this_weekend';
      case 'Next weekend':
        return 'next_weekend';
      default:
        return null;
    }
  }

  String? get _categoryTypeParam {
    switch (selectedCategoryType.value) {
      case 'Club':
        return 'CLUB';
      case 'Concert':
        return 'CONCERT';
      case 'Festival':
        return 'FESTIVAL';
      case 'Open air':
        return 'OPEN_AIR';
      case 'Warehouse':
        return 'WAREHOUSE';
      default:
        return null;
    }
  }

  DateTime? get _selectedDate {
    if (_dateFilter != null) return null;
    if (selectedDateOption.value == 'Custom date') return _customDate;
    return null;
  }

  static DateTime weekendSaturday(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (today.weekday == DateTime.saturday) return today;
    if (today.weekday == DateTime.sunday) {
      return today.subtract(const Duration(days: 1));
    }
    return today.add(Duration(days: DateTime.saturday - today.weekday));
  }

  String? get _selectedCity {
    if (selectedLocation.value == 'Any location') return null;
    if (selectedLocation.value == 'Current location') {
      return cityFromAddress(currentLocation.value?.address ?? '');
    }
    final place = selectedPlace.value;
    if (place != null && place.primaryText.trim().isNotEmpty) {
      return place.primaryText.trim();
    }
    final value = selectedLocation.value.trim();
    return value.isEmpty ? null : value.split(',').first.trim();
  }

  static String? cityFromAddress(String address) {
    final value = address.trim();
    if (value.isEmpty) return null;
    return value.split(',').first.trim();
  }

  DateTime? get _customDate {
    final value = customDateController.text.trim();
    if (value.isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  (double?, double?) _priceBounds(String option) {
    switch (option) {
      case 'Free':
        return (null, 0);
      case 'Max €15':
        return (null, 15);
      case 'Under €20':
        return (null, 20);
      case '€25 to €100':
        return (25, 100);
      case '€100 to €300':
        return (100, 300);
      case '€300 to €500':
        return (300, 500);
      case 'Custom price':
        final minimum = double.tryParse(minimumPriceController.text.trim());
        final maximum = double.tryParse(maximumPriceController.text.trim());
        if (minimum != null && maximum != null && minimum > maximum) {
          return (maximum, minimum);
        }
        return (minimum, maximum);
      default:
        return (null, null);
    }
  }

  double? _ratingMinimum(String option) {
    switch (option) {
      case '4.5+':
        return 4.5;
      case '4.00 - 4.5':
        return 4;
      case '3.5 - 4.00':
        return 3.5;
      default:
        return null;
    }
  }

  @override
  void onClose() {
    _placeSearchDebounce?.cancel();
    _searchDebounce?.cancel();
    searchFocus.dispose();
    searchController.dispose();
    locationSearchController.dispose();
    customDateController.dispose();
    moodController.dispose();
    minimumPriceController.dispose();
    maximumPriceController.dispose();
    super.onClose();
  }
}
