import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../club_details_view/views/club_details_view.dart';
import '../../explore/widget/club_event_card.dart';
import '../../explore/widget/explore_shimmer.dart';
import '../controllers/wishlist_controller.dart';

class FavoriteClubeView extends StatefulWidget {
  const FavoriteClubeView({super.key});

  @override
  State<FavoriteClubeView> createState() => _FavoriteClubeViewState();
}

class _FavoriteClubeViewState extends State<FavoriteClubeView> {
  late final WishlistController controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<WishlistController>()
        ? Get.find<WishlistController>()
        : Get.put(WishlistController(), permanent: true);
    _scrollController = ScrollController()..addListener(_onScroll);
    controller.fetchWishlist(refresh: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(
        title: "Favorites",
        centerTitle: true,
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.items.isEmpty) {
          return const ExploreListShimmer(compact: false);
        }

        if (controller.items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: CompactEmptyState.stacked(
                icon: Icons.favorite_border_rounded,
                title: 'No favorites yet',
                message: 'Save a club or event to see it here.',
              ),
            ),
          );
        }

        final showFooter = controller.isLoadingMore.value;
        final itemCount = controller.items.length + (showFooter ? 1 : 0);

        return RefreshIndicator(
          color: const Color(0xFFE1B144),
          backgroundColor: Colors.black,
          onRefresh: () => controller.fetchWishlist(refresh: true),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 130),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 25),
            itemBuilder: (context, index) {
              if (index >= controller.items.length) {
                return const ExploreEventCardShimmer(compact: false);
              }

              final itemData = controller.items[index];
              return GestureDetector(
                onTap: () => Get.to(
                  () => ClubDetailsView(
                    clubModel: itemData,
                    isFavorite: true,
                  ),
                ),
                child: ClubEventCard(club: itemData),
              );
            },
          ),
        );
      }),
    );
  }
}
