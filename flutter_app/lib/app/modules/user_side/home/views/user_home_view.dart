import '../widgets/discovery_feed_section.dart';
import 'package:bookdianight_app/app/core/utils/resource_const.dart';
import 'package:bookdianight_app/app/modules/user_side/club_details_view/views/club_details_view.dart';
import 'package:bookdianight_app/app/modules/user_side/home/views/see_all_popular_club_view.dart';
import 'package:bookdianight_app/app/modules/user_side/home/views/tonight_near_you_view.dart';
import '../../../../core/auth/account_gate.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../notification/controller/notification_controller.dart';
import '../../../notification/views/notification_view.dart';
import '../../explore/widget/club_event_card.dart';
import '../controllers/club_controller.dart';
import '../controllers/user_location_controller.dart';
import '../model/vip_table_deal_model.dart';
import '../widgets/club_list_tile.dart';
import '../widgets/home_reuseble.dart';
import '../widgets/home_shimmer.dart';
import '../widgets/vip_table_deal_card.dart';
import 'explore_vip_table.dart';
import '../../../profile/controllers/profile_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ClubController>()
        ? Get.find<ClubController>()
        : Get.put(ClubController());
    Get.put(UserLocationController());
    final discovery = Get.isRegistered<DiscoveryFeedController>()
        ? Get.find<DiscoveryFeedController>()
        : Get.put(DiscoveryFeedController());
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    final notifications = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController());

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: controller.dismissHomeSearch,
          behavior: HitTestBehavior.translucent,
          child: RefreshIndicator(
          color: const Color(0xFFE1B144),
          backgroundColor: Colors.black,
          onRefresh: () async {
            await Future.wait([
              controller.loadHomeSections(),
              discovery.load(),
              notifications.fetch(refresh: true),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(profileController, notifications),
                const SizedBox(height: 25),
                _HomeSearchField(controller: controller),
                const SizedBox(height: 25),

                DiscoveryFeedSection(controller: discovery),

                /// Tonight Near You
                CommonComponents.sectionHeader(
                  'Tonight near you',
                  () => Get.to(() => const TonightNearYouView()),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final tonightLoading = controller.isTonightLoading.value &&
                      controller.tonightClubs.isEmpty;
                  final tonightPreview = controller.tonightClubs
                      .take(ClubController.homePreviewLimit)
                      .toList(growable: false);
                  final tonightEmpty = !tonightLoading && tonightPreview.isEmpty;

                  if (tonightEmpty) {
                    return const CompactEmptyState(
                      icon: Icons.nights_stay_outlined,
                      title: 'No venues tonight',
                      message: 'Nearby venues will appear here.',
                    );
                  }
                  if (tonightLoading) {
                    return const HomeCarouselShimmer();
                  }
                  return SizedBox(
                    height: CommonComponents.homeCardHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tonightPreview.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final club = tonightPreview[index];
                        return GestureDetector(
                          onTap: () => Get.to(
                            () => ClubDetailsView(
                              clubModel: club,
                            ),
                          ),
                          child: ClubEventCard(
                            club: club,
                            width: CommonComponents.homeCardWidth,
                            imageHeight: CommonComponents.homeCardHeight,
                            ratingAsBadge: true,
                          ),
                        );
                      },
                    ),
                  );
                }),
                const SizedBox(height: 22),

                /// Popular Clubs
                CommonComponents.sectionHeader(
                  'Popular clubs',
                  () => Get.to(() => const SeeAllPopularClubView()),
                ),
                const SizedBox(height: 10),
                Obx(() {
                  if (controller.isPopularLoading.value &&
                      controller.popularClubs.isEmpty) {
                    return const HomePopularListShimmer();
                  }

                  final popularPreview = controller.popularClubs
                      .take(5)
                      .toList(growable: false);

                  if (popularPreview.isEmpty) {
                    return const CompactEmptyState(
                      icon: Icons.local_fire_department_outlined,
                      title: 'No popular clubs',
                      message: 'Popular clubs will appear here.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: popularPreview.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 15),
                    itemBuilder: (context, index) {
                      final club = popularPreview[index];
                      return GestureDetector(
                        onTap: () => Get.to(
                          () => ClubDetailsView(
                            clubModel: club,
                          ),
                        ),
                        child: ClubListTile(club: club),
                      );
                    },
                  );
                }),
                const SizedBox(height: 25),


                CommonComponents.sectionHeader(
                  'VIP table deals',
                  () => Get.to(() => const ExploreVipTable()),
                ),
                const SizedBox(height: 15),
                Obx(() {
                  if (controller.isVipLoading.value &&
                      controller.vipClubs.isEmpty) {
                    return const HomeVipListShimmer();
                  }

                  final vipPreview = controller.vipClubs
                      .take(ClubController.homePreviewLimit)
                      .toList(growable: false);

                  if (vipPreview.isEmpty) {
                    return const CompactEmptyState(
                      icon: Icons.workspace_premium_outlined,
                      title: 'No VIP tables',
                      message: 'VIP table deals will appear here.',
                    );
                  }

                  return SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: vipPreview.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final club = vipPreview[index];
                        return VipTableDealCard(
                          deal: VipTableDealModel(
                            imageUrl: club.image,
                            title: club.title,
                            priceLabel: club.price.isEmpty
                                ? ''
                                : 'From ${club.price}',
                          ),
                          width: MediaQuery.sizeOf(context).width - 56,
                          onTap: () => Get.to(
                            () => ClubDetailsView(
                              clubModel: club,
                              initialTab: 'Tables',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ProfileController profileController,
    NotificationController notifications,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => CustomText(
                text: profileController.userName.value.isNotEmpty
                    ? "Hi, ${profileController.userName.value}"
                    : AccountGate.isSignedIn
                    ? "Hi, User"
                    : "Hi, Guest",
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const CustomText(
              text: "Let’s find various clubs\naround you!",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ],
        ),
        Obx(() {
          notifications.notifications.length;
          final badge = notifications.badgeLabel;
          return InkWell(
            onTap: () async {
              if (!await AccountGate.ensure()) return;
              Get.to(() => const NotificationView());
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.notifications_none, color: Colors.white),
                ),
                if (badge.isNotEmpty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1B144),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _HomeSearchField extends StatelessWidget {
  const _HomeSearchField({required this.controller});

  final ClubController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTextField(
          controller: controller.homeSearchController,
          focusNode: controller.homeSearchFocus,
          hint: 'Search clubs and events',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: Obx(() {
            if (controller.homeSearchQuery.value.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              onPressed: controller.clearHomeSearch,
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
            );
          }),
          onChanged: controller.onHomeSearchChanged,
          fillColor: Colors.white.withValues(alpha: 0.05),
          filled: true,
          isBorder: true,
          borderColor: Colors.white24,
          borderRadius: 15,
        ),
        const _HomeSearchResults(),
      ],
    );
  }
}

class _HomeSearchResults extends StatelessWidget {
  const _HomeSearchResults();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ClubController>();
    return Obx(() {
      final query = controller.homeSearchQuery.value.trim();
      final focused = controller.homeSearchFocused.value;
      final ready = controller.homeSearchReadyQuery.value.trim() == query;
      final loading = controller.isHomeSearching.value;
      if (!focused || query.isEmpty || (!loading && !ready)) {
        return const SizedBox.shrink();
      }

      final results = controller.homeSearchResults.toList(growable: false);
      final clubs =
          results.where((item) => !item.isEvent).toList(growable: false);
      final events =
          results.where((item) => item.isEvent).toList(growable: false);

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: () {},
          child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: loading
              ? const SizedBox(
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE1B144),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CompactEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No results',
                        message: 'Try another name or location.',
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SearchGroup(
                            title: 'Clubs',
                            items: clubs,
                            showDivider: events.isNotEmpty,
                          ),
                          _SearchGroup(title: 'Events', items: events),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      );
    });
  }
}

class _SearchGroup extends StatelessWidget {
  const _SearchGroup({
    required this.title,
    required this.items,
    this.showDivider = false,
  });

  final String title;
  final List<ClubModel> items;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: CustomText(
            text: title,
            color: const Color(0xFFE1B144),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        for (var index = 0; index < items.length; index++) ...[
          _SearchSuggestionTile(
            club: items[index],
            onTap: () {
              final controller = Get.find<ClubController>();
              final club = items[index];
              controller.dismissHomeSearch();
              controller.clearHomeSearch();
              Get.to(() => ClubDetailsView(clubModel: club));
            },
          ),
          if (index != items.length - 1)
            const Divider(height: 1, thickness: 1, indent: 74, color: Colors.white10),
        ],
        if (showDivider)
          const Divider(height: 16, thickness: 1, color: Colors.white10),
      ],
    );
  }
}

class _SearchSuggestionTile extends StatelessWidget {
  const _SearchSuggestionTile({required this.club, required this.onTap});

  final ClubModel club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isEvent = club.isEvent;
    final location = club.location.trim().isEmpty
        ? 'Location unavailable'
        : club.location.trim();
    final price = club.price.trim();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _SearchThumb(imageUrl: club.image),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomText(
                          text: club.title,
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          maxLine: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypeTag(isEvent: isEvent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: CustomText(
                          text: location,
                          color: Colors.grey,
                          fontSize: 11,
                          maxLine: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (price.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: CustomText(
                            text: isEvent ? price : 'From $price',
                            color: const Color(0xFFE1B144),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            maxLine: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.isEvent});

  final bool isEvent;

  @override
  Widget build(BuildContext context) {
    final color = isEvent ? const Color(0xFFE1B144) : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: CustomText(
        text: isEvent ? 'Event' : 'Club',
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        maxLine: 1,
      ),
    );
  }
}

class _SearchThumb extends StatelessWidget {
  const _SearchThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_outlined, color: Colors.white38, size: 20),
      );
    }

    return CustomNetworkImage(
      imageUrl: imageUrl,
      height: 48,
      width: 48,
      borderRadius: BorderRadius.circular(12),
      fit: BoxFit.cover,
    );
  }
}
