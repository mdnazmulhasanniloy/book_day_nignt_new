import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bookdianight_app/app/modules/user_side/home/controllers/club_controller.dart';
import 'package:bookdianight_app/app/modules/user_side/club_details_view/views/club_details_view.dart';

import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../explore/widget/club_event_card.dart';

class TonightNearYouView extends StatefulWidget {
  const TonightNearYouView({super.key});

  @override
  State<TonightNearYouView> createState() => _TonightNearYouViewState();
}

class _TonightNearYouViewState extends State<TonightNearYouView> {
  late final ClubController controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ClubController>()
        ? Get.find<ClubController>()
        : Get.put(ClubController());
    _scrollController = ScrollController()..addListener(_onScroll);

    // See-all should load paginated pages from page 1.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchTonight(
        refresh: true,
        limit: ClubController.seeAllPageLimit,
      );
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      controller.fetchTonight(limit: ClubController.seeAllPageLimit);
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
        title: "Tonight near you",
        backgroundColor: Colors.black,
      ),
      body: Obx(() {
        if (controller.isTonightLoading.value &&
            controller.tonightClubs.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE1B144),
              strokeWidth: 2,
            ),
          );
        }

        if (controller.tonightClubs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: CompactEmptyState.stacked(
                icon: Icons.nights_stay_outlined,
                title: 'No venues tonight',
                message: 'Nearby venues will appear here.',
              ),
            ),
          );
        }

        final showFooter = controller.isTonightLoadingMore.value;
        final itemCount = controller.tonightClubs.length + (showFooter ? 1 : 0);

        return RefreshIndicator(
          color: const Color(0xFFE1B144),
          backgroundColor: Colors.black,
          onRefresh: () => controller.fetchTonight(
            refresh: true,
            limit: ClubController.seeAllPageLimit,
          ),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              if (index >= controller.tonightClubs.length) {
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

              final club = controller.tonightClubs[index];
              return GestureDetector(
                onTap: () => Get.to(
                  () => ClubDetailsView(
                    clubModel: club,
                  ),
                ),
                child: ClubEventCard(
                  club: club,
                  ratingAsBadge: true,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
