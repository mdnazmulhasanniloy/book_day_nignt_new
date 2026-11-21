import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bookdianight_app/app/modules/user_side/club_details_view/views/club_details_view.dart';

import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../controllers/club_controller.dart';
import '../widgets/club_list_tile.dart';

class SeeAllPopularClubView extends StatefulWidget {
  const SeeAllPopularClubView({super.key});

  @override
  State<SeeAllPopularClubView> createState() => _SeeAllPopularClubViewState();
}

class _SeeAllPopularClubViewState extends State<SeeAllPopularClubView> {
  late final ClubController controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ClubController>()
        ? Get.find<ClubController>()
        : Get.put(ClubController());
    _scrollController = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchPopular(
        refresh: true,
        limit: ClubController.seeAllPageLimit,
      );
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      controller.fetchPopular(limit: ClubController.seeAllPageLimit);
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
        title: "Popular clubs",
        backgroundColor: Colors.black,
      ),
      body: Obx(() {
        if (controller.isPopularLoading.value &&
            controller.popularClubs.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE1B144),
              strokeWidth: 2,
            ),
          );
        }

        if (controller.popularClubs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: CompactEmptyState.stacked(
                icon: Icons.local_fire_department_outlined,
                title: 'No popular clubs',
                message: 'Popular clubs will appear here.',
              ),
            ),
          );
        }

        final showFooter = controller.isPopularLoadingMore.value;
        final itemCount = controller.popularClubs.length + (showFooter ? 1 : 0);

        return RefreshIndicator(
          color: const Color(0xFFE1B144),
          backgroundColor: Colors.black,
          onRefresh: () => controller.fetchPopular(
            refresh: true,
            limit: ClubController.seeAllPageLimit,
          ),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              if (index >= controller.popularClubs.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE1B144),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final club = controller.popularClubs[index];
              return GestureDetector(
                onTap: () => Get.to(
                  () => ClubDetailsView(
                    clubModel: club,
                  ),
                ),
                child: ClubListTile(club: club),
              );
            },
          ),
        );
      }),
    );
  }
}
