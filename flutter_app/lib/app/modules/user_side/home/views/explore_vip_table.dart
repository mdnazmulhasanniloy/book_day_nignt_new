import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bookdianight_app/app/modules/user_side/club_details_view/views/club_details_view.dart';

import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../explore/widget/club_event_card.dart';
import '../controllers/club_controller.dart';

class ExploreVipTable extends StatefulWidget {
  const ExploreVipTable({super.key});

  @override
  State<ExploreVipTable> createState() => _ExploreVipTableState();
}

class _ExploreVipTableState extends State<ExploreVipTable> {
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
      controller.fetchVipClubs(
        refresh: true,
        limit: ClubController.seeAllPageLimit,
      );
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      controller.fetchVipClubs(limit: ClubController.seeAllPageLimit);
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
        title: "VIP table deals",
        backgroundColor: Colors.black,
      ),
      body: Obx(() {
        if (controller.isVipLoading.value && controller.vipClubs.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE1B144),
              strokeWidth: 2,
            ),
          );
        }

        final clubs = controller.vipTableClubs;
        if (clubs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: CompactEmptyState.stacked(
                icon: Icons.workspace_premium_outlined,
                title: 'No VIP tables',
                message: 'VIP table deals will appear here.',
              ),
            ),
          );
        }

        final showFooter = controller.isVipLoadingMore.value;
        final itemCount = clubs.length + (showFooter ? 1 : 0);

        return RefreshIndicator(
          color: const Color(0xFFE1B144),
          backgroundColor: Colors.black,
          onRefresh: () => controller.fetchVipClubs(
            refresh: true,
            limit: ClubController.seeAllPageLimit,
          ),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              if (index >= clubs.length) {
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

              final club = clubs[index];
              return GestureDetector(
                onTap: () => Get.to(
                  () => ClubDetailsView(
                    clubModel: club,
                    initialTab: 'Tables',
                  ),
                ),
                child: ClubEventCard(
                  club: club,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
