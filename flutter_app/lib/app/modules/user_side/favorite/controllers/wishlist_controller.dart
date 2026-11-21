import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/auth/account_gate.dart';
import '../../../../core/explore/model/explore_item_mapper.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../explore/controllers/explore_controller.dart';
import '../../home/controllers/club_controller.dart';
import '../repository/wishlist_repository.dart';

class WishlistController extends GetxController {
  WishlistController({WishlistRepository? repository})
    : _repository = repository ?? WishlistRepository();

  final WishlistRepository _repository;

  static const int pageLimit = 10;

  /// Realtime wishlist flags keyed by `TYPE_id`.
  final statusByKey = <String, bool>{}.obs;
  final items = <ClubModel>[].obs;
  final togglingKeys = <String>{}.obs;

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final total = 0.obs;

  int _page = 0;

  static String keyFor(String id, String type) =>
      '${type.trim().toUpperCase()}_$id';

  bool isWishlisted(ClubModel club) {
    if (club.id.isEmpty) return club.isWishlist;
    return statusByKey[keyFor(club.id, club.type)] ?? club.isWishlist;
  }

  bool isToggling(ClubModel club) =>
      club.id.isNotEmpty && togglingKeys.contains(keyFor(club.id, club.type));

  void syncFromItem(ClubModel club) {
    if (club.id.isEmpty) return;
    statusByKey[keyFor(club.id, club.type)] = club.isWishlist;
  }

  void syncFromList(Iterable<ClubModel> list) {
    for (final club in list) {
      syncFromItem(club);
    }
    statusByKey.refresh();
  }

  Future<void> fetchWishlist({bool refresh = false}) async {
    if (!AccountGate.isSignedIn) return;
    if (refresh) {
      _page = 0;
      hasMore.value = true;
    }

    if (!hasMore.value && !refresh) return;
    if (isLoading.value || isLoadingMore.value) return;

    if (refresh || items.isEmpty) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    final nextPage = _page + 1;

    try {
      final response = await _repository.getWishlist(
        page: nextPage,
        limit: pageLimit,
      );
      final mapped = await withEventSchedules(
        response.data.map((item) => item.toClubModel()).toList(),
      );

      if (refresh || nextPage == 1) {
        items.assignAll(mapped);
      } else {
        items.addAll(mapped);
      }

      syncFromList(mapped);
      _page = nextPage;
      total.value = response.meta.total;
      hasMore.value = nextPage < response.meta.totalPages;
    } catch (e) {
      debugPrint('Wishlist fetch error: $e');
      if (refresh || items.isEmpty) {
        CustomSnackBar.error(message: 'Failed to load favorites');
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() => fetchWishlist(refresh: false);

  Future<void> toggle(ClubModel club) async {
    if (!await AccountGate.ensure()) return;
    if (club.id.isEmpty) return;

    final key = keyFor(club.id, club.type);
    if (togglingKeys.contains(key)) return;

    final currentlyWishlisted = isWishlisted(club);
    final nextValue = !currentlyWishlisted;

    togglingKeys.add(key);
    togglingKeys.refresh();
    _applyStatus(club, nextValue);

    try {
      if (nextValue) {
        await _repository.addToWishlist(id: club.id, type: club.type);
      } else {
        await _repository.removeFromWishlist(id: club.id, type: club.type);
      }
    } catch (e) {
      debugPrint('Wishlist toggle error: $e');
      _applyStatus(club, currentlyWishlisted);
      CustomSnackBar.error(
        message: nextValue
            ? 'Failed to add to favorites'
            : 'Failed to remove from favorites',
      );
    } finally {
      togglingKeys.remove(key);
      togglingKeys.refresh();
    }
  }

  void _applyStatus(ClubModel club, bool value) {
    final key = keyFor(club.id, club.type);
    statusByKey[key] = value;
    statusByKey.refresh();

    _updateListItem(items, club.id, club.type, value);

    if (value) {
      final exists = items.any(
        (item) =>
            item.id == club.id &&
            item.type.toUpperCase() == club.type.toUpperCase(),
      );
      if (!exists) {
        items.insert(0, club.copyWith(isWishlist: true));
      }
    } else {
      items.removeWhere(
        (item) =>
            item.id == club.id &&
            item.type.toUpperCase() == club.type.toUpperCase(),
      );
    }

    if (Get.isRegistered<ClubController>()) {
      final clubController = Get.find<ClubController>();
      _updateListItem(clubController.tonightClubs, club.id, club.type, value);
      _updateListItem(clubController.popularClubs, club.id, club.type, value);
      _updateListItem(clubController.vipClubs, club.id, club.type, value);
    }

    if (Get.isRegistered<ExploreController>()) {
      final exploreController = Get.find<ExploreController>();
      _updateListItem(
        exploreController.filteredVenues,
        club.id,
        club.type,
        value,
      );
    }
  }

  void _updateListItem(
    RxList<ClubModel> list,
    String id,
    String type,
    bool value,
  ) {
    final index = list.indexWhere(
      (item) =>
          item.id == id && item.type.toUpperCase() == type.toUpperCase(),
    );
    if (index < 0) return;
    list[index] = list[index].copyWith(isWishlist: value);
  }
}
