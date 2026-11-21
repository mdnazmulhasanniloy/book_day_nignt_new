import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/explore/model/explore_api_model.dart';
import '../../../../core/explore/model/explore_item_mapper.dart';
import '../../../../core/explore/repository/explore_api_repository.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../model/club_model.dart';
import 'user_location_controller.dart';
import '../../favorite/controllers/wishlist_controller.dart';

export '../model/club_model.dart';

class ClubController extends GetxController {
  ClubController({ExploreApiRepository? repository})
    : _repository = repository ?? ExploreApiRepository();

  final ExploreApiRepository _repository;

  static const int homePreviewLimit = 10;
  static const int seeAllPageLimit = 10;

  final tonightClubs = <ClubModel>[].obs;
  final popularClubs = <ClubModel>[].obs;
  final vipClubs = <ClubModel>[].obs;

  final isTonightLoading = false.obs;
  final isPopularLoading = false.obs;
  final isVipLoading = false.obs;
  final isTonightLoadingMore = false.obs;
  final isPopularLoadingMore = false.obs;
  final isVipLoadingMore = false.obs;

  final tonightTotal = 0.obs;
  final popularTotal = 0.obs;
  final vipTotal = 0.obs;
  final tonightHasMore = false.obs;
  final popularHasMore = false.obs;
  final vipHasMore = false.obs;

  final homeSearchController = TextEditingController();
  final homeSearchFocus = FocusNode();
  final homeSearchQuery = ''.obs;
  final homeSearchFocused = false.obs;
  final homeSearchResults = <ClubModel>[].obs;
  final isHomeSearching = false.obs;
  final homeSearchReadyQuery = ''.obs;
  Timer? _homeSearchDebounce;
  int _homeSearchToken = 0;

  int _tonightPage = 0;
  int _popularPage = 0;
  int _vipPage = 0;

  @override
  void onInit() {
    super.onInit();
    homeSearchFocus.addListener(_onHomeSearchFocus);
    loadHomeSections();
  }

  @override
  void onClose() {
    _homeSearchDebounce?.cancel();
    homeSearchFocus.removeListener(_onHomeSearchFocus);
    homeSearchFocus.dispose();
    homeSearchController.dispose();
    super.onClose();
  }

  void _onHomeSearchFocus() {
    homeSearchFocused.value = homeSearchFocus.hasFocus;
  }

  void dismissHomeSearch() {
    homeSearchFocus.unfocus();
  }

  void onHomeSearchChanged(String value) {
    homeSearchQuery.value = value;
    _scheduleHomeSearch();
  }

  void clearHomeSearch() {
    _homeSearchDebounce?.cancel();
    _homeSearchToken++;
    homeSearchController.clear();
    homeSearchQuery.value = '';
    homeSearchResults.clear();
    homeSearchReadyQuery.value = '';
    isHomeSearching.value = false;
  }

  void _scheduleHomeSearch() {
    _homeSearchDebounce?.cancel();
    final query = homeSearchQuery.value.trim();
    if (query.isEmpty) {
      _homeSearchToken++;
      homeSearchResults.clear();
      homeSearchReadyQuery.value = '';
      isHomeSearching.value = false;
      return;
    }
    if (query == homeSearchReadyQuery.value) return;
    _homeSearchDebounce = Timer(
      const Duration(milliseconds: 650),
      () => searchHome(query),
    );
  }

  Future<void> searchHome(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty || normalized != homeSearchQuery.value.trim()) return;
    final token = ++_homeSearchToken;
    isHomeSearching.value = true;
    try {
      final response = await _repository.getExplore(
        ExploreQueryModel(search: normalized, page: 1, limit: 8),
      );
      if (token != _homeSearchToken) return;
      homeSearchResults.assignAll(
        await withEventSchedules(
          response.data
              .map((item) => item.toClubModel())
              .toList(growable: false),
        ),
      );
      homeSearchReadyQuery.value = normalized;
    } catch (error) {
      debugPrint('Home search error: $error');
      if (token != _homeSearchToken) return;
      homeSearchResults.clear();
      homeSearchReadyQuery.value = normalized;
    } finally {
      if (token == _homeSearchToken) {
        isHomeSearching.value = false;
      }
    }
  }

  Future<void> loadHomeSections() async {
    await Future.wait([
      fetchTonight(refresh: true, limit: homePreviewLimit),
      fetchPopular(refresh: true, limit: homePreviewLimit),
      fetchVipClubs(refresh: true, limit: homePreviewLimit),
    ]);
  }

  Future<void> fetchTonight({
    bool refresh = false,
    int limit = seeAllPageLimit,
  }) async {
    if (refresh) {
      _tonightPage = 0;
      tonightHasMore.value = true;
    }

    if (!tonightHasMore.value && !refresh) return;
    if (isTonightLoading.value || isTonightLoadingMore.value) return;

    if (refresh || tonightClubs.isEmpty) {
      isTonightLoading.value = true;
    } else {
      isTonightLoadingMore.value = true;
    }

    final nextPage = _tonightPage + 1;

    try {
      final coords = await _resolveCoordinates();
      final now = DateTime.now();
      final response = await _repository.getExplore(
        ExploreQueryModel(
          date: DateTime(now.year, now.month, now.day),
          latitude: coords.$1,
          longitude: coords.$2,
          page: nextPage,
          limit: limit,
        ),
      );

      final items = await withEventSchedules(
        response.data.map((item) => item.toClubModel()).toList(),
      );
      if (refresh || nextPage == 1) {
        tonightClubs.assignAll(items);
      } else {
        tonightClubs.addAll(items);
      }
      _syncWishlist(items);

      _tonightPage = nextPage;
      tonightTotal.value = response.meta.total;
      tonightHasMore.value = nextPage < response.meta.totalPages;
    } catch (e) {
      debugPrint('Tonight fetch error: $e');
      if (refresh || tonightClubs.isEmpty) {
        CustomSnackBar.error(message: 'Failed to load tonight venues');
      }
    } finally {
      isTonightLoading.value = false;
      isTonightLoadingMore.value = false;
    }
  }

  Future<void> fetchPopular({
    bool refresh = false,
    int limit = seeAllPageLimit,
  }) async {
    if (refresh) {
      _popularPage = 0;
      popularHasMore.value = true;
    }

    if (!popularHasMore.value && !refresh) return;
    if (isPopularLoading.value || isPopularLoadingMore.value) return;

    if (refresh || popularClubs.isEmpty) {
      isPopularLoading.value = true;
    } else {
      isPopularLoadingMore.value = true;
    }

    final nextPage = _popularPage + 1;

    try {
      final response = await _repository.getExplore(
        ExploreQueryModel(
          type: 'CLUB',
          isPopular: true,
          page: nextPage,
          limit: limit,
        ),
      );

      final items = response.data.map((item) => item.toClubModel()).toList();
      if (refresh || nextPage == 1) {
        popularClubs.assignAll(items);
      } else {
        popularClubs.addAll(items);
      }
      _syncWishlist(items);

      _popularPage = nextPage;
      popularTotal.value = response.meta.total;
      popularHasMore.value = nextPage < response.meta.totalPages;
    } catch (e) {
      debugPrint('Popular fetch error: $e');
      if (refresh || popularClubs.isEmpty) {
        CustomSnackBar.error(message: 'Failed to load popular clubs');
      }
    } finally {
      isPopularLoading.value = false;
      isPopularLoadingMore.value = false;
    }
  }

  Future<void> fetchVipClubs({
    bool refresh = false,
    int limit = seeAllPageLimit,
  }) async {
    if (refresh) {
      _vipPage = 0;
      vipHasMore.value = true;
    }

    if (!vipHasMore.value && !refresh) return;
    if (isVipLoading.value || isVipLoadingMore.value) return;

    if (refresh || vipClubs.isEmpty) {
      isVipLoading.value = true;
    } else {
      isVipLoadingMore.value = true;
    }

    final nextPage = _vipPage + 1;

    try {
      final response = await _repository.getExplore(
        ExploreQueryModel(
          type: 'CLUB',
          isVip: true,
          page: nextPage,
          limit: limit,
        ),
      );

      final items = response.data
          .map((item) => item.toClubModel())
          .where((club) => club.type.toLowerCase() == 'club')
          .toList();
      if (refresh || nextPage == 1) {
        vipClubs.assignAll(items);
      } else {
        vipClubs.addAll(items);
      }
      _syncWishlist(items);

      _vipPage = nextPage;
      vipTotal.value = response.meta.total;
      vipHasMore.value = nextPage < response.meta.totalPages;
    } catch (e) {
      debugPrint('VIP clubs fetch error: $e');
      if (refresh || vipClubs.isEmpty) {
        CustomSnackBar.error(message: 'Failed to load VIP table deals');
      }
    } finally {
      isVipLoading.value = false;
      isVipLoadingMore.value = false;
    }
  }

  Future<(double?, double?)> _resolveCoordinates() async {
    final locationController = Get.isRegistered<UserLocationController>()
        ? Get.find<UserLocationController>()
        : Get.put(UserLocationController());

    var location = locationController.currentLocation.value;
    if (location == null || !location.isAvailable) {
      location = await locationController.loadCurrentLocation();
    }

    if (location.isAvailable) {
      return (location.latitude, location.longitude);
    }
    return (null, null);
  }

  void _syncWishlist(List<ClubModel> items) {
    try {
      if (!Get.isRegistered<WishlistController>()) return;
      Get.find<WishlistController>().syncFromList(items);
    } catch (e) {
      debugPrint('Wishlist sync skipped: $e');
    }
  }

  List<ClubModel> get vipTableClubs => vipClubs.toList(growable: false);
}
