import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../club_details_view/views/club_details_view.dart';
import '../controllers/explore_controller.dart';
import '../sheets/explore_filter_sheet.dart';
import '../widget/club_event_card.dart';
import '../widget/explore_shimmer.dart';
import 'explore_with_map_view.dart';

class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  late final ExploreController controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ExploreController>()
        ? Get.find<ExploreController>()
        : Get.put(ExploreController());
    _scrollController = ScrollController()..addListener(_onScroll);
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
      resizeToAvoidBottomInset: false,
      appBar: const CustomAppBar(
        title: 'Explore',
        centerTitle: true,
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: GestureDetector(
        onTap: controller.dismissSearchFocus,
        behavior: HitTestBehavior.translucent,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: controller.searchController,
                    focusNode: controller.searchFocus,
                    hint: 'Search clubs and events...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: Obx(
                      () => controller.searchQuery.value.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              onPressed: () {
                                controller.searchController.clear();
                                controller.onSearchChanged('');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    onChanged: controller.onSearchChanged,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    filled: true,
                    isBorder: true,
                    borderColor: Colors.white24,
                    borderRadius: 15,
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => Get.bottomSheet(
                    const FilterBottomSheet(),
                    isScrollControlled: true,
                    ignoreSafeArea: false,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE1B144),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value &&
                        controller.filteredVenues.isEmpty) {
                      return const ExploreCountShimmer();
                    }
                    return RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14),
                        children: [
                          TextSpan(
                            text: '${controller.totalVenues.value} ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: 'venues found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton(Icons.list_rounded, true, () {}),
                      _buildToggleButton(
                        Icons.map_outlined,
                        false,
                        () => Get.to(
                          () => MapOverviewScreen(
                            venues: controller.filteredVenues.toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.filteredVenues.isEmpty) {
                return const ExploreListShimmer();
              }

              final venues = controller.filteredVenues;
              if (venues.isEmpty) {
                return _EmptyResult(
                  onReset: () {
                    controller.searchController.clear();
                    controller.searchQuery.value = '';
                    controller.resetFilters();
                  },
                );
              }

              final showFooter = controller.isLoadingMore.value;
              final itemCount = venues.length + (showFooter ? 1 : 0);

              return RefreshIndicator(
                color: const Color(0xFFE1B144),
                backgroundColor: Colors.black,
                onRefresh: () => controller.fetchVenues(refresh: true),
                child: ListView.separated(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 130),
                  itemCount: itemCount,
                  separatorBuilder: (_, _) => const SizedBox(height: 25),
                  itemBuilder: (context, index) {
                    if (index >= venues.length) {
                      return const ExploreEventCardShimmer();
                    }

                    final venue = venues[index];
                    return InkWell(
                      onTap: () => Get.to(
                        () => ClubDetailsView(
                          clubModel: venue,
                        ),
                      ),
                      child: ClubEventCard(
                        club: venue,
                        ratingAsBadge: true,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildToggleButton(IconData icon, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.grey,
          size: 20,
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: CompactEmptyState.stacked(
          icon: Icons.search_off_rounded,
          title: 'No venues found',
          message: 'Try another search or clear your filters.',
          action: TextButton(
            onPressed: onReset,
            child: const Text(
              'Clear filters',
              style: TextStyle(color: Color(0xFFE1B144)),
            ),
          ),
        ),
      ),
    );
  }
}
