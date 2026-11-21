import '../../../../core/explore/repository/discovery_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/explore/model/explore_api_model.dart';
import '../../../../core/explore/repository/explore_api_repository.dart';
import '../../favorite/controllers/wishlist_controller.dart';
import '../../home/controllers/club_controller.dart';
import '../model/club_review_model.dart';
import '../repository/club_review_repository.dart';

class ClubDetailsController extends GetxController {
  ClubDetailsController({
    required this.seedClub,
    this.initialTab,
    ExploreApiRepository? repository,
    ClubReviewRepository? reviewRepository,
  }) : _repository = repository ?? ExploreApiRepository(),
       _reviewRepository = reviewRepository ?? ClubReviewRepository();

  final ClubModel seedClub;
  final String? initialTab;
  final ExploreApiRepository _repository;
  final ClubReviewRepository _reviewRepository;

  late final RxList<String> tabs;
  final selectedTabIndex = 0.obs;
  final isFavorite = false.obs;

  final isLoading = true.obs;
  final errorMessage = RxnString();
  final detail = Rxn<ExploreDetailModel>();
  late final Rx<ClubModel> displayClub;

  final organizer = Rxn<Map<String, dynamic>>();
  final photos = <String>[].obs;
  final tablePackages = <Map<String, dynamic>>[].obs;
  final reviews = <ClubReviewModel>[].obs;
  final isReviewsLoading = false.obs;
  final isReviewsLoadingMore = false.obs;
  final reviewsHasMore = false.obs;
  final averageRating = RxnDouble();
  final reviewsTotal = RxnInt();
  static const int reviewPageLimit = 10;
  int _reviewPage = 0;
  var _reviewsBusy = false;

  Worker? _wishlistWorker;

  WishlistController get _wishlistController =>
      Get.isRegistered<WishlistController>()
      ? Get.find<WishlistController>()
      : Get.put(WishlistController(), permanent: true);

  /// Always `CLUB` or `EVENT` for `/explore/:id?type=...`
  String get apiType {
    final raw = seedClub.type.trim().toUpperCase();
    if (raw == 'EVENT' || raw.contains('EVENT')) return 'EVENT';
    return 'CLUB';
  }

  bool get isClub => apiType == 'CLUB';

  bool get isPastEvent {
    final loaded = detail.value;
    final end = loaded?.endAt ?? displayClub.value.endAt;
    if (isClub) return false;
    final status = (loaded?.eventStatus ?? '').trim().toUpperCase();
    if (status == 'COMPLETED' ||
        status == 'CANCELED' ||
        status == 'CANCELLED') {
      return true;
    }
    return end != null && end.isBefore(DateTime.now());
  }

  bool get canBuyTicket =>
      !isClub && !isPastEvent && detail.value?.bookingsClosed != true;

  ClubModel get clubModel => displayClub.value;

  @override
  void onInit() {
    super.onInit();
    displayClub = seedClub.obs;
    tabs =
        (isClub
                ? ['About', 'Photos', 'Tables', 'Reviews']
                : ['About', 'Photos'])
            .obs;

    final requestedTab = initialTab?.trim();
    if (requestedTab != null && requestedTab.isNotEmpty) {
      final index = tabs.indexWhere(
        (tab) => tab.toLowerCase() == requestedTab.toLowerCase(),
      );
      if (index >= 0) selectedTabIndex.value = index;
    }

    isFavorite.value = _wishlistController.isWishlisted(seedClub);
    _wishlistWorker = ever<Map<String, bool>>(_wishlistController.statusByKey, (
      _,
    ) {
      isFavorite.value = _wishlistController.isWishlisted(displayClub.value);
    });

    loadDetails();
  }

  @override
  void onClose() {
    _wishlistWorker?.dispose();
    super.onClose();
  }

  void changeTab(int index) => selectedTabIndex.value = index;

  Future<void> toggleFavorite() async {
    await _wishlistController.toggle(displayClub.value);
    isFavorite.value = _wishlistController.isWishlisted(displayClub.value);
  }

  Future<void> loadDetails({bool showLoading = true}) async {
    if (seedClub.id.isEmpty) {
      isLoading.value = false;
      errorMessage.value = 'Invalid venue id';
      return;
    }

    if (showLoading) {
      isLoading.value = true;
      errorMessage.value = null;
    }

    try {
      final response = await _repository.getExploreDetails(
        id: seedClub.id,
        type: apiType,
      );
      final data = response.data;
      if (!response.success || data == null) {
        throw StateError(
          response.message.isEmpty
              ? 'Failed to load details'
              : response.message,
        );
      }

      detail.value = data;
      _bindDetail(data);
      await _loadOrganizer(data);
      errorMessage.value = null;
    } catch (e, stack) {
      debugPrint('Explore details error: $e');
      debugPrint('$stack');
      if (showLoading || detail.value == null) {
        errorMessage.value = e
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', '');
      }
    } finally {
      if (showLoading) {
        isLoading.value = false;
      }
    }
  }

  Future<void> _loadOrganizer(ExploreDetailModel data) async {
    organizer.value = null;
    if (isClub) {
      organizer.value = {
        'id': data.id,
        'name': data.name,
        'thumbnail': data.thumbnail,
        if (data.followerCount != null) 'followerCount': data.followerCount,
      };
      return;
    }
    // Follow endpoints accept club IDs, never an organizer/owner/event ID.
    final linked = data.linkedClub;
    final id = data.associatedClubId;
    if (id == null || id.trim().isEmpty) return;
    if (linked != null && '${linked['name'] ?? ''}'.trim().isNotEmpty) {
      organizer.value = {...linked, 'id': id};
      return;
    }
    try {
      final body = await DiscoveryRepository().get(
        '/explore/${Uri.encodeComponent(id)}',
        params: {'type': 'CLUB'},
      );
      if (!isClosed) organizer.value = DiscoveryRepository.data(body);
    } catch (_) {
      /* Missing linked clubs cannot become an event follow target. */
    }
  }

  void _bindDetail(ExploreDetailModel data) {
    final typeLabel = isClub ? 'Club' : 'Event';
    final priceLabel = _formatPrice(data);
    final rating = data.aggregateRating != null && data.aggregateRating! > 0
        ? data.aggregateRating!.toStringAsFixed(1)
        : '';

    final updated = seedClub.copyWith(
      id: data.id.isNotEmpty ? data.id : seedClub.id,
      title: data.name.isNotEmpty ? data.name : seedClub.title,
      image: data.thumbnail.isNotEmpty ? data.thumbnail : seedClub.image,
      location: data.location,
      rating: rating,
      price: priceLabel.isNotEmpty ? priceLabel : seedClub.price,
      type: typeLabel,
      latitude: data.latitude ?? seedClub.latitude,
      longitude: data.longitude ?? seedClub.longitude,
      isWishlist: data.isWishlist,
      isVip: data.isVip ?? seedClub.isVip,
      tags: (data.isVip ?? false) ? <String>['VIP'] : seedClub.tags,
    );
    displayClub.value = updated;

    _wishlistController.syncFromItem(updated);
    isFavorite.value = _wishlistController.isWishlisted(updated);

    photos.assignAll(<String>{
      if (data.thumbnail.trim().isNotEmpty) data.thumbnail,
      ...data.images.where((image) => image.trim().isNotEmpty),
    });

    final packages = [...data.packages]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    tablePackages.assignAll(
      packages
          .where((package) => package.isActive)
          .map(
            (package) => <String, dynamic>{
              'title': package.name,
              'price': _money(package.price),
              'capacity': '${package.capacity} guests',
              'features': package.features,
              'description': package.description,
            },
          )
          .toList(growable: false),
    );

    loadReviews(refresh: true);
  }

  Future<void> loadReviews({bool refresh = false}) async {
    if (!isClub) return;
    final clubId = displayClub.value.id.trim().isNotEmpty
        ? displayClub.value.id
        : seedClub.id;
    if (clubId.trim().isEmpty || _reviewsBusy) return;
    if (refresh) {
      _reviewPage = 0;
      reviewsHasMore.value = true;
    }
    if (!reviewsHasMore.value && !refresh) return;

    final nextPage = _reviewPage + 1;
    _reviewsBusy = true;
    if (refresh || reviews.isEmpty) {
      isReviewsLoading.value = true;
    } else {
      isReviewsLoadingMore.value = true;
    }

    try {
      final page = await _reviewRepository.fetchReviews(
        clubId: clubId,
        page: nextPage,
        limit: reviewPageLimit,
      );
      if (refresh) reviews.clear();
      reviews.addAll(page.reviews);
      _reviewPage = nextPage;
      reviewsHasMore.value = page.hasMore;
      reviewsTotal.value = page.total;
      if (page.averageRating > 0) {
        averageRating.value = page.averageRating;
      }
    } catch (error, stack) {
      debugPrint('Club reviews error: $error');
      debugPrint('$stack');
      if (refresh) {
        reviews.clear();
        reviewsHasMore.value = false;
      }
    } finally {
      _reviewsBusy = false;
      isReviewsLoading.value = false;
      isReviewsLoadingMore.value = false;
    }
  }

  Future<void> loadMoreReviews() => loadReviews();

  String _formatPrice(ExploreDetailModel data) {
    if (isClub) {
      if (data.packages.isEmpty) return '';
      final prices = data.packages
          .where((package) => package.isActive)
          .map((package) => package.price)
          .toList();
      if (prices.isEmpty) return '';
      prices.sort();
      return _money(prices.first);
    }
    final starting = data.startingPrice;
    if (starting == null) return '';
    return _money(starting);
  }

  String _money(double amount) {
    final value = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '€$value';
  }

  String formatDateTime(DateTime? value) {
    if (value == null) return '--';
    return DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
  }

  String formatOpeningHour(ExploreOpeningHourModel hours) {
    if (hours.isClosed) return 'Closed';
    final open = _timeLabel(hours.openTime);
    final close = _timeLabel(hours.closeTime);
    final overnight = _closesAfterMidnight(hours.openTime, hours.closeTime);
    return overnight ? '$open – $close (+1 day)' : '$open – $close';
  }

  bool _closesAfterMidnight(DateTime open, DateTime close) {
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;
    return closeMinutes <= openMinutes;
  }

  String dayLabel(int dayOfWeek) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    if (dayOfWeek < 0 || dayOfWeek >= days.length) return 'Day $dayOfWeek';
    return days[dayOfWeek];
  }

  String _timeLabel(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String statusLabel(String? status) {
    final value = (status ?? '').trim().toUpperCase();
    if (value.isEmpty) return '--';
    return value[0] + value.substring(1).toLowerCase();
  }
}
