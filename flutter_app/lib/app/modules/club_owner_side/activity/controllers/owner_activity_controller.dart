import 'package:get/get.dart';

import '../../../../core/explore/model/event_commerce_model.dart';
import '../../../../core/explore/model/event_offer_model.dart';
import '../../../../core/network/api_expection.dart';
import '../../../../core/utils/cst_time.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../../../core/utils/location_helpfer_function.dart';
import '../model/club_api_model.dart';
import '../model/club_upsert_model.dart';
import '../model/event_api_model.dart';
import '../model/promo_api_model.dart';
import '../repository/club_repository.dart';
import '../repository/event_repository.dart';
import '../repository/promo_repository.dart';

class ActivityItemModel {
  final String id;
  final String title;
  final String type; // "Club" or "Event"
  final String image;
  final String location;
  final String rating;
  final String price;
  String status; // "Upcoming", "Completed", "Canceled", "Active"
  final String description;
  final String openingHours;
  final String dressCode;
  List<Map<String, dynamic>>? packages;
  final List<String> images;
  final double latitude;
  final double longitude;
  final bool isRecurring;
  final bool isVip;
  final int? totalReviews;
  final List<ClubOpeningHourModel> openingHoursData;
  final List<ClubPackageModel> clubPackages;
  final DateTime? startAt;
  final DateTime? endAt;
  final double? eventPrice;
  final String currency;
  final bool isActive;
  final String? eventStatus;
  final DateTime? deactivatedAt;
  final String? clubId;
  final String clubName;
  final List<EventTicketTierModel> ticketTiers;
  final List<EventLineupArtistModel> lineup;
  final List<String> musicGenres;
  final String categoryType;
  bool bookingsClosed;
  List<String> hostIds;

  ActivityItemModel({
    required this.id,
    required this.title,
    required this.type,
    required this.image,
    required this.location,
    required this.rating,
    required this.price,
    required this.status,
    this.description = '',
    this.openingHours = '',
    this.dressCode = '',
    this.packages,
    this.images = const [],
    this.latitude = 0,
    this.longitude = 0,
    this.isRecurring = false,
    this.isVip = false,
    this.totalReviews,
    this.openingHoursData = const [],
    this.clubPackages = const [],
    this.startAt,
    this.endAt,
    this.eventPrice,
    this.currency = 'EUR',
    this.isActive = true,
    this.eventStatus,
    this.deactivatedAt,
    this.clubId,
    this.clubName = '',
    this.ticketTiers = const [],
    this.lineup = const [],
    this.musicGenres = const [],
    this.categoryType = 'CLUB',
    this.bookingsClosed = false,
    this.hostIds = const [],
  });
}

class OwnerActivityController extends GetxController {
  static const int _pageLimit = 10;

  OwnerActivityController({
    ClubRepository? clubRepository,
    EventRepository? eventRepository,
    PromoRepository? promoRepository,
  }) : _clubRepository = clubRepository ?? ClubRepository(),
       _eventRepository = eventRepository ?? EventRepository(),
       _promoRepository = promoRepository ?? PromoRepository();

  final ClubRepository _clubRepository;
  final EventRepository _eventRepository;
  final PromoRepository _promoRepository;

  // Main Tab: 0 = Club, 1 = Event, 2 = Promo
  var selectedMainTab = 0.obs;

  // Event status filter: 0 = Upcoming, 1 = Completed. Clubs have no status tabs.
  var selectedStatusFilter = 0.obs;

  final List<String> mainTabs = ["Club", "Event", "Promo"];
  final List<String> eventStatusFilters = ["Upcoming", "Completed"];

  // Create Type selection in bottom sheet: "Club" or "Event"
  var selectedCreateType = "Club".obs;

  final activityList = <ActivityItemModel>[].obs;
  final promoList = <PromoDataModel>[].obs;
  bool _promoListUnsupported = false;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final editingEventId = ''.obs;
  final errorMessage = ''.obs;
  final Set<String> _loadedTypes = {};
  final Set<String> _loadingTypes = {};
  final Map<String, int> _currentPages = {};
  final Map<String, int> _totalPages = {};

  String get _requestKey {
    if (selectedMainTab.value == 0) return 'CLUB';
    if (selectedMainTab.value == 2) return 'PROMO';
    return selectedStatusFilter.value == 1 ? 'EVENT_COMPLETED' : 'EVENT_UPCOMING';
  }

  bool get isPromoTab => selectedMainTab.value == 2;

  String? get _eventStatusQuery {
    if (selectedMainTab.value != 1) return null;
    return selectedStatusFilter.value == 1 ? 'COMPLETED' : 'UPCOMING';
  }

  bool get hasMoreForCurrentType {
    final key = _requestKey;
    return (_currentPages[key] ?? 0) < (_totalPages[key] ?? 1);
  }

  @override
  void onInit() {
    super.onInit();
    fetchActivities();
  }

  // Clubs show every club. Events are split by the selected status tab.
  List<ActivityItemModel> get filteredList {
    if (isPromoTab) return const [];
    final targetType = mainTabs[selectedMainTab.value];
    if (targetType == 'Club') {
      return activityList
          .where((item) => item.type.toLowerCase() == 'club')
          .toList();
    }

    final statusIndex = selectedStatusFilter.value.clamp(
      0,
      eventStatusFilters.length - 1,
    );
    final targetStatus = eventStatusFilters[statusIndex];
    return activityList.where((item) {
      return item.type.toLowerCase() == 'event' &&
          item.status.toLowerCase() == targetStatus.toLowerCase();
    }).toList();
  }

  Future<void> changeMainTab(int index) async {
    if (index == selectedMainTab.value) return;
    selectedMainTab.value = index;
    if (selectedStatusFilter.value >= eventStatusFilters.length) {
      selectedStatusFilter.value = 0;
    }
    errorMessage.value = '';
    await fetchActivities();
  }

  Future<void> changeStatusFilter(int index) async {
    if (index == selectedStatusFilter.value) return;
    selectedStatusFilter.value = index;
    errorMessage.value = '';
    await fetchActivities();
  }

  Future<void> fetchActivities({bool forceRefresh = false}) async {
    final key = _requestKey;
    if (!forceRefresh && _loadedTypes.contains(key)) return;
    if (_loadingTypes.contains(key)) return;

    _loadingTypes.add(key);
    isLoading.value = true;
    errorMessage.value = '';
    try {
      if (key == 'PROMO') {
        await _loadPromos(page: 1, replace: true);
        _currentPages[key] = 1;
        _loadedTypes.add(key);
        return;
      }

      List<ActivityItemModel> items = [];
      if (key == 'CLUB') {
        final response = await _clubRepository.getOwnClubs(
          page: 1,
          limit: _pageLimit,
        );
        if (!response.success) {
          throw StateError(
            response.message.isEmpty
                ? 'Could not load clubs'
                : response.message,
          );
        }
        items = await Future.wait(response.data.map(_mapClubItem));
        _totalPages[key] = _normalizedTotalPages(
          response.meta.totalPages,
          response.data.length,
        );
      } else {
        final response = await _eventRepository.getOwnEvents(
          page: 1,
          limit: _pageLimit,
          eventStatus: _eventStatusQuery,
        );
        if (!response.success) {
          throw StateError(
            response.message.isEmpty
                ? 'Could not load activities'
                : response.message,
          );
        }

        items = await _withEventSchedules(
          await Future.wait(
            response.data.map(
              (item) => _mapEventItem(
                item,
                fullAddress: false,
                listStatus: _eventStatusQuery,
              ),
            ),
          ),
        );
        _totalPages[key] = _normalizedTotalPages(
          response.meta.totalPages,
          response.data.length,
        );
      }

      _replaceItemsForKey(key, items);
      _currentPages[key] = 1;
      _loadedTypes.add(key);
    } catch (error) {
      // A failed initial request must not be treated as page 1 waiting to be
      // loaded by pagination. Otherwise the view schedules the same request
      // again after every rebuild.
      _stopPaginationFor(key);
      if (_requestKey == key &&
          (!isPromoTab || promoList.isEmpty)) {
        errorMessage.value = _readableError(error);
      }
    } finally {
      _loadingTypes.remove(key);
      isLoading.value = _loadingTypes.contains(_requestKey);
    }
  }

  Future<void> refreshCurrentType() {
    if (isPromoTab) _promoListUnsupported = false;
    return fetchActivities(forceRefresh: true);
  }

  void rememberCreatedPromo(PromoDataModel promo) {
    selectedMainTab.value = 2;
    selectedCreateType.value = 'Club';
    _upsertPromo(promo, insertFirst: true);
    errorMessage.value = '';
    if (_promoListUnsupported) return;
    _loadedTypes.remove('PROMO');
    fetchActivities(forceRefresh: true);
  }

  void rememberUpdatedPromo(PromoDataModel promo) {
    selectedMainTab.value = 2;
    _upsertPromo(promo, insertFirst: false);
    errorMessage.value = '';
    if (_promoListUnsupported) return;
    _loadedTypes.remove('PROMO');
    fetchActivities(forceRefresh: true);
  }

  void _upsertPromo(PromoDataModel promo, {required bool insertFirst}) {
    if (promo.code.trim().isEmpty) return;
    promoList.removeWhere(
      (item) =>
          (item.id.isNotEmpty && item.id == promo.id) ||
          item.code.toUpperCase() == promo.code.toUpperCase(),
    );
    if (insertFirst) {
      promoList.insert(0, promo);
    } else {
      promoList.insert(0, promo);
    }
  }

  Future<void> deletePromo(PromoDataModel promo) async {
    final id = promo.id.trim();
    if (id.isEmpty) return;
    try {
      await _promoRepository.deletePromo(id);
      promoList.removeWhere(
        (item) =>
            (item.id.isNotEmpty && item.id == id) ||
            item.code.toUpperCase() == promo.code.toUpperCase(),
      );
      CustomSnackBar.success(message: 'Promo code deleted');
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not delete promo'),
      );
    }
  }

  Future<int> _loadPromos({required int page, required bool replace}) async {
    if (_promoListUnsupported && page > 1) {
      _totalPages['PROMO'] = 1;
      return 0;
    }
    try {
      final response = await _promoRepository.getOwnPromos(
        page: page,
        limit: _pageLimit,
      );
      _promoListUnsupported = false;
      if (!response.success && response.data.isEmpty) {
        throw StateError(
          response.message.isEmpty
              ? 'Could not load promo codes'
              : response.message,
        );
      }
      _totalPages['PROMO'] = _normalizedTotalPages(
        response.totalPages,
        response.data.length,
        currentPage: page,
      );
      if (replace) {
        promoList.assignAll(response.data);
      } else {
        for (final item in response.data) {
          final index = promoList.indexWhere(
            (existing) =>
                (existing.id.isNotEmpty && existing.id == item.id) ||
                existing.code.toUpperCase() == item.code.toUpperCase(),
          );
          if (index == -1) {
            promoList.add(item);
          } else {
            promoList[index] = item;
          }
        }
        promoList.refresh();
      }
      return response.data.length;
    } catch (error) {
      if (!_isMissingPromoList(error)) rethrow;
      _promoListUnsupported = true;
      _totalPages['PROMO'] = 1;
      return 0;
    }
  }

  bool _isMissingPromoList(Object error) {
    if (error is NotFoundException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('route not found') ||
        text.contains('cannot get /api/v1/promo');
  }

  Future<void> loadMoreActivities() async {
    if (isLoading.value ||
        isLoadingMore.value ||
        errorMessage.value.isNotEmpty ||
        !hasMoreForCurrentType) {
      return;
    }

    final key = _requestKey;
    final eventStatus = _eventStatusQuery;
    isLoadingMore.value = true;
    try {
      var visibleCount = filteredList.length;
      do {
        if (_requestKey != key) break;
        final nextPage = (_currentPages[key] ?? 0) + 1;
        List<ActivityItemModel> newItems;
        int totalPages;

        if (key == 'PROMO') {
          final count = await _loadPromos(page: nextPage, replace: false);
          _currentPages[key] = nextPage;
          if (count < _pageLimit) break;
          continue;
        }

        if (key == 'CLUB') {
          final response = await _clubRepository.getOwnClubs(
            page: nextPage,
            limit: _pageLimit,
          );
          if (!response.success) {
            throw StateError(
              response.message.isEmpty
                  ? 'Could not load more clubs'
                  : response.message,
            );
          }
          newItems = await Future.wait(response.data.map(_mapClubItem));
          totalPages = _normalizedTotalPages(
            response.meta.totalPages,
            response.data.length,
            currentPage: nextPage,
          );
        } else {
          final response = await _eventRepository.getOwnEvents(
            page: nextPage,
            limit: _pageLimit,
            eventStatus: eventStatus,
          );
          if (!response.success) {
            throw StateError(
              response.message.isEmpty
                  ? 'Could not load more activities'
                  : response.message,
            );
          }
          newItems = await _withEventSchedules(
            await Future.wait(
              response.data.map(
                (item) => _mapEventItem(
                  item,
                  fullAddress: false,
                  listStatus: eventStatus,
                ),
              ),
            ),
          );
          totalPages = _normalizedTotalPages(
            response.meta.totalPages,
            response.data.length,
            currentPage: nextPage,
          );
        }

        _currentPages[key] = nextPage;
        _totalPages[key] = totalPages;
        _appendUniqueItems(newItems);

        final newVisibleCount = filteredList.length;
        if (newVisibleCount > visibleCount || !hasMoreForCurrentType) break;
        visibleCount = newVisibleCount;
      } while (hasMoreForCurrentType && _requestKey == key);
    } catch (error) {
      // Keep the already loaded items, but stop automatic retries for the
      // failed next page. Pull-to-refresh can start a clean request again.
      _stopPaginationFor(key);
      if (_requestKey == key) {
        errorMessage.value = _readableError(error);
      }
    } finally {
      isLoadingMore.value = false;
    }
  }

  void _replaceItemsForKey(String key, List<ActivityItemModel> items) {
    if (key == 'CLUB') {
      activityList.removeWhere((item) => item.type.toUpperCase() == 'CLUB');
    } else if (key == 'EVENT_COMPLETED') {
      activityList.removeWhere(
        (item) =>
            item.type.toUpperCase() == 'EVENT' &&
            item.status.toLowerCase() == 'completed',
      );
    } else {
      activityList.removeWhere(
        (item) =>
            item.type.toUpperCase() == 'EVENT' &&
            item.status.toLowerCase() == 'upcoming',
      );
    }
    activityList.addAll(items);
  }

  void _stopPaginationFor(String type) {
    _totalPages[type] = _currentPages[type] ?? 0;
  }

  int _normalizedTotalPages(
    int apiTotalPages,
    int receivedCount, {
    int currentPage = 1,
  }) {
    if (apiTotalPages > 0) return apiTotalPages;
    return receivedCount < _pageLimit ? currentPage : currentPage + 1;
  }

  void _appendUniqueItems(List<ActivityItemModel> items) {
    for (final item in items) {
      final index = activityList.indexWhere(
        (existing) => existing.id == item.id,
      );
      if (index == -1) {
        activityList.add(item);
      } else {
        activityList[index] = item;
      }
    }
    activityList.refresh();
  }

  Future<ActivityItemModel> getActivityDetails(
    ActivityItemModel fallback,
  ) async {
    if (fallback.type.toUpperCase() == 'CLUB') {
      final response = await _clubRepository.getClubDetail(fallback.id);
      final detail = response.data;
      if (!response.success || detail == null) {
        throw StateError(
          response.message.isEmpty
              ? 'Could not load club details'
              : response.message,
        );
      }
      return _mapClubDetailToActivity(detail, fallback);
    } else {
      final response = await _eventRepository.getEventDetail(fallback.id);
      final detail = response.data;
      if (!response.success || detail == null) {
        throw StateError(
          response.message.isEmpty
              ? 'Could not load activity details'
              : response.message,
        );
      }
      return _mapEventItem(
        detail,
        fullAddress: true,
        previousHostIds: fallback.hostIds,
      );
    }
  }

  Future<ActivityItemModel> _mapClubDetailToActivity(
    ClubDataModel detail,
    ActivityItemModel fallback,
  ) async {
    final openingHours = detail.clubOpeningHours
        .map(
          (hours) => ClubOpeningHourModel(
            id: hours['id']?.toString(),
            dayOfWeek: _asInt(hours['dayOfWeek']),
            isClosed: _asBool(hours['isClosed']),
            openTime: _asDateTime(hours['openTime']),
            closeTime: _asDateTime(hours['closeTime']),
            closesNextDay: _asBool(hours['closesNextDay']),
          ),
        )
        .toList(growable: false);
    final packages = detail.clubPackages
        .map(
          (package) => ClubPackageModel(
            id: package['id']?.toString(),
            name: package['name']?.toString() ?? '',
            description: package['description']?.toString() ?? '',
            capacity: _asInt(package['capacity'], fallback: 1),
            price: _asDouble(package['price']),
            currency: _valueOrFallback(
              package['currency']?.toString() ?? '',
              'EUR',
            ),
            features:
                (package['features'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            sortOrder: _asInt(package['sortOrder']),
            isActive: _asBool(package['isActive'], fallback: true),
          ),
        )
        .toList(growable: false);

    final location = await LocationHelperFunction.getFullAddressFromLatLng(
      lat: detail.lat,
      lng: detail.lng,
      fallback: '',
    );

    final previous =
        activityList.firstWhereOrNull((item) => item.id == fallback.id) ??
        fallback;
    final isActive = detail.activeFlagPresent
        ? detail.isActive
        : previous.isActive;
    final deactivatedAt = detail.activeFlagPresent
        ? detail.deactivatedAt
        : previous.deactivatedAt;

    return ActivityItemModel(
      id: detail.id.trim().isEmpty ? fallback.id : detail.id,
      title: _valueOrFallback(detail.name, fallback.title),
      type: fallback.type,
      image: _valueOrFallback(detail.thumbnail, fallback.image),
      location: location,
      rating: detail.review == null
          ? fallback.rating
          : _ratingLabel(detail.review!),
      price: detail.minPrice != null
          ? _fromPriceLabel(detail.minPrice!)
          : packages.any((package) => package.isActive)
          ? _minimumPackagePrice(packages)
          : fallback.price,
      status: isActive ? 'Active' : 'Inactive',
      description: detail.description,
      openingHours: openingHours.isEmpty
          ? 'Opening hours unavailable'
          : _openingHoursLabel(openingHours),
      dressCode: detail.dressCode,
      images: detail.images,
      latitude: detail.lat,
      longitude: detail.lng,
      isRecurring: detail.isRecurring,
      isVip: detail.isVip,
      isActive: isActive,
      deactivatedAt: deactivatedAt,
      openingHoursData: openingHours,
      clubPackages: packages,
    );
  }

  Future<ActivityItemModel> _mapEventItem(
    EventDataModel item, {
    required bool fullAddress,
    String? listStatus,
    List<String>? previousHostIds,
  }) async {
    final savedLocation = item.location.trim();
    final location = fullAddress && savedLocation.isNotEmpty
        ? savedLocation
        : fullAddress
        ? await LocationHelperFunction.getFullAddressFromLatLng(
            lat: item.latitude,
            lng: item.longitude,
          )
        : await LocationHelperFunction.getCityCountryFromLatLng(
            lat: item.latitude,
            lng: item.longitude,
          );
    final priceValue = item.eventPrice == item.eventPrice.roundToDouble()
        ? item.eventPrice.toInt().toString()
        : item.eventPrice.toStringAsFixed(2);
    return ActivityItemModel(
      id: item.id,
      title: item.eventName,
      type: 'Event',
      image: item.thumbnail,
      location: location,
      rating: '',
      price: '€$priceValue',
      status: _statusLabel(
        item.eventStatus.trim().isEmpty ? listStatus : item.eventStatus,
      ),
      description: item.eventDescription,
      dressCode: item.dressCode,
      images: item.images,
      latitude: item.latitude,
      longitude: item.longitude,
      startAt: _usableDate(item.startAt),
      endAt: _usableDate(item.endAt),
      eventPrice: item.eventPrice,
      currency: 'EUR',
      isActive: item.isActive,
      eventStatus: item.eventStatus,
      deactivatedAt: item.deactivatedAt,
      clubId: item.clubId,
      clubName: item.clubName,
      ticketTiers: item.ticketTiers,
      lineup: item.lineup,
      musicGenres: item.musicGenres,
      categoryType: item.categoryType,
      bookingsClosed: item.bookingsClosed,
      hostIds: _hostIdsFrom(
        item.hosts,
        previousHostIds ??
            activityList.firstWhereOrNull((e) => e.id == item.id)?.hostIds,
      ),
    );
  }

  Future<ActivityItemModel> _mapClubItem(ClubDataModel item) async {
    final minPrice = item.minPrice ?? _lowestPackagePrice(item.clubPackages);
    final priceLabel = minPrice == null ? '--' : _fromPriceLabel(minPrice);

    final locationLabel = await LocationHelperFunction.getCityCountryFromLatLng(
      lat: item.lat,
      lng: item.lng,
    );

    var isActive = item.isActive;
    var deactivatedAt = item.deactivatedAt;
    if (!item.activeFlagPresent) {
      final previous = activityList.firstWhereOrNull((e) => e.id == item.id);
      if (previous != null) {
        isActive = previous.isActive;
        deactivatedAt = previous.deactivatedAt;
      }
    }
    final status = isActive ? 'Active' : 'Inactive';

    return ActivityItemModel(
      id: item.id,
      title: item.name,
      type: 'Club',
      image: item.thumbnail,
      location: locationLabel,
      rating: _ratingLabel(item.review ?? 0),
      price: priceLabel,
      status: status,
      latitude: item.lat,
      longitude: item.lng,
      isRecurring: item.isRecurring,
      isVip: item.isVip,
      isActive: isActive,
      deactivatedAt: deactivatedAt,
    );
  }

  String _ratingLabel(double review) {
    if (review == 0) return '0';
    return review.toStringAsFixed(1);
  }

  String _fromPriceLabel(double amount) {
    final value = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return 'From €$value';
  }

  double? _lowestPackagePrice(List<Map<String, dynamic>> packages) {
    final activePackages = packages
        .where((package) => _asBool(package['isActive'], fallback: true))
        .toList(growable: false);
    if (activePackages.isEmpty) return null;
    var lowest = _asDouble(activePackages.first['price']);
    for (final package in activePackages.skip(1)) {
      final price = _asDouble(package['price']);
      if (price < lowest) lowest = price;
    }
    return lowest;
  }

  String _statusLabel(String? value) {
    switch (value?.trim().toUpperCase()) {
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELED':
      case 'CANCELLED':
        return 'Canceled';
      default:
        return 'Upcoming';
    }
  }

  String _readableError(Object error) {
    final message = error.toString();
    return message
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    switch (value?.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
      default:
        return fallback;
    }
  }

  DateTime _asDateTime(dynamic value) => clubClockFromIso(value);

  String _valueOrFallback(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value;
  }

  String _minimumPackagePrice(List<ClubPackageModel> packages) {
    final activePackages =
        packages.where((package) => package.isActive).toList(growable: false)
          ..sort((first, second) => first.price.compareTo(second.price));
    if (activePackages.isEmpty) return '--';
    final package = activePackages.first;
    final value = package.price == package.price.roundToDouble()
        ? package.price.toInt().toString()
        : package.price.toStringAsFixed(2);
    return 'From €$value';
  }

  String _openingHoursLabel(List<ClubOpeningHourModel> openingHours) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final activeHours = openingHours
        .where((hours) => !hours.isClosed)
        .toList(growable: false);
    if (activeHours.isEmpty) return 'Closed';

    final dayNames = activeHours
        .where((hours) => hours.dayOfWeek >= 0 && hours.dayOfWeek < days.length)
        .map((hours) => days[hours.dayOfWeek])
        .join(', ');
    final first = activeHours.first;
    return '$dayNames: ${_timeLabel(first.openTime)} - ${_timeLabel(first.closeTime)}';
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<ActivityItemModel?> prepareEventEditor(ActivityItemModel item) async {
    if (editingEventId.value.isNotEmpty) return null;
    editingEventId.value = item.id;
    try {
      final full = await getActivityDetails(item);
      _keepListLocation(item, full);
      return full;
    } catch (error) {
      CustomSnackBar.error(message: _readableError(error));
      return null;
    } finally {
      if (editingEventId.value == item.id) editingEventId.value = '';
    }
  }

  Future<List<ActivityItemModel>> _withEventSchedules(
    List<ActivityItemModel> items,
  ) {
    return Future.wait(
      items.map((item) async {
        if (item.type.toUpperCase() != 'EVENT' || _usableDate(item.startAt) != null) {
          return item;
        }
        try {
          final response = await _eventRepository.getEventDetail(item.id);
          final detail = response.data;
          if (!response.success || detail == null) return item;
          return ActivityItemModel(
            id: item.id,
            title: item.title.trim().isEmpty ? detail.eventName : item.title,
            type: item.type,
            image: item.image,
            location: item.location,
            rating: item.rating,
            price: item.price,
            status: item.status,
            description: detail.eventDescription,
            dressCode: detail.dressCode,
            images: detail.images,
            latitude: item.latitude,
            longitude: item.longitude,
            startAt: _usableDate(detail.startAt),
            endAt: _usableDate(detail.endAt),
            eventPrice: item.eventPrice ?? detail.eventPrice,
            currency: item.currency,
            isActive: detail.isActive,
            eventStatus: detail.eventStatus.trim().isEmpty
                ? item.eventStatus
                : detail.eventStatus,
            deactivatedAt: detail.deactivatedAt,
            clubId: detail.clubId ?? item.clubId,
            clubName: detail.clubName.isNotEmpty ? detail.clubName : item.clubName,
            ticketTiers: detail.ticketTiers.isNotEmpty
                ? detail.ticketTiers
                : item.ticketTiers,
            lineup: detail.lineup.isNotEmpty ? detail.lineup : item.lineup,
            musicGenres: detail.musicGenres.isNotEmpty
                ? detail.musicGenres
                : item.musicGenres,
            categoryType: detail.categoryType.isNotEmpty
                ? detail.categoryType
                : item.categoryType,
            bookingsClosed: detail.bookingsClosed,
            hostIds: _hostIdsFrom(detail.hosts, item.hostIds),
          );
        } catch (_) {
          return item;
        }
      }),
    );
  }

  void _keepListLocation(ActivityItemModel current, ActivityItemModel full) {
    final index = activityList.indexWhere((item) => item.id == current.id);
    if (index == -1) return;
    activityList[index] = ActivityItemModel(
      id: current.id,
      title: current.title,
      type: current.type,
      image: current.image,
      location: current.location,
      rating: current.rating,
      price: current.price,
      status: current.status,
      description: full.description,
      dressCode: full.dressCode,
      images: full.images,
      latitude: current.latitude,
      longitude: current.longitude,
      startAt: full.startAt,
      endAt: full.endAt,
      eventPrice: full.eventPrice ?? current.eventPrice,
      currency: current.currency,
      isActive: full.isActive,
      eventStatus: full.eventStatus ?? current.eventStatus,
      deactivatedAt: full.deactivatedAt,
      isVip: current.isVip,
      isRecurring: current.isRecurring,
      openingHoursData: full.openingHoursData.isNotEmpty
          ? full.openingHoursData
          : current.openingHoursData,
      clubPackages: full.clubPackages.isNotEmpty
          ? full.clubPackages
          : current.clubPackages,
      clubId: full.clubId ?? current.clubId,
      clubName: full.clubName.isNotEmpty ? full.clubName : current.clubName,
      ticketTiers: full.ticketTiers.isNotEmpty
          ? full.ticketTiers
          : current.ticketTiers,
      lineup: full.lineup.isNotEmpty ? full.lineup : current.lineup,
      musicGenres: full.musicGenres.isNotEmpty
          ? full.musicGenres
          : current.musicGenres,
      categoryType: full.categoryType.isNotEmpty
          ? full.categoryType
          : current.categoryType,
      bookingsClosed: full.bookingsClosed,
      hostIds: full.hostIds.isNotEmpty ? full.hostIds : current.hostIds,
    );
    activityList.refresh();
  }

  DateTime? _usableDate(DateTime? value) {
    if (value == null || value.year < 2000) return null;
    return value;
  }

  List<String> _hostIdsFrom(
    List<EventHostModel> hosts,
    List<String>? previous,
  ) {
    final fromApi = hosts
        .map((host) => host.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (fromApi.isNotEmpty) return fromApi;
    return List<String>.from(previous ?? const []);
  }

  void addActivityItem(ActivityItemModel newItem) {
    activityList.removeWhere((item) => item.id == newItem.id);
    activityList.insert(0, newItem);
    _loadedTypes.add(newItem.type.toUpperCase());
    activityList.refresh();
  }

  void updateActivityItem(ActivityItemModel updatedItem) {
    int index = activityList.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      activityList[index] = updatedItem;
      activityList.refresh();
    }
  }

  /// New events belong on Upcoming. Drop the cached event lists and reload
  /// that tab so a stale Completed insert cannot hide the event.
  Future<void> reloadCreatedEvent() async {
    selectedMainTab.value = 1;
    selectedStatusFilter.value = 0;
    _loadedTypes.remove('EVENT_UPCOMING');
    _loadedTypes.remove('EVENT_COMPLETED');
    activityList.removeWhere((item) => item.type.toUpperCase() == 'EVENT');
    await fetchActivities(forceRefresh: true);
  }

  Future<void> upsertEventFromApi(EventDataModel event) async {
    final mapped = await _mapEventItem(
      event,
      fullAddress: false,
      listStatus: event.eventStatus,
    );
    final hydrated = await _withEventSchedules([mapped]);
    final item = hydrated.first;
    final index = activityList.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      activityList.insert(0, item);
    } else {
      activityList[index] = item;
    }
    activityList.refresh();
  }
}
