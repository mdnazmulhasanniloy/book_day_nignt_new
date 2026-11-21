import '../../../../core/explore/model/event_offer_model.dart';
import '../../home/views/organizers_view.dart';
import 'event_details_view.dart';
import '../widgets/club_community_section.dart';
import '../widgets/event_commerce_section.dart';
import '../widgets/waiting_list_panel.dart';
import '../../../../core/resources/common_widget/address_from_coordinates.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../services/deep_link_service.dart';
import '../../home/controllers/club_controller.dart';
import '../controllers/club_details_controller.dart';
import '../widgets/club_bottom_action_bar.dart';
import '../widgets/club_sliver_app_bar.dart';
import '../widgets/club_tab_content.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

/// Keeps existing routes compatible while event and club screens have distinct entries.
class ClubDetailsView extends StatelessWidget {
  const ClubDetailsView({super.key, required this.clubModel, this.isFavorite, this.initialTab});
  final ClubModel clubModel;
  final bool? isFavorite;
  final String? initialTab;
  @override
  Widget build(BuildContext context) => clubModel.isEvent
      ? EventDetailsView(clubModel: clubModel, isFavorite: isFavorite, initialTab: initialTab)
      : VenueDetailsView(clubModel: clubModel, isFavorite: isFavorite, initialTab: initialTab);
}

class VenueDetailsView extends StatefulWidget {
  final ClubModel clubModel;
  final bool? isFavorite;
  final String? initialTab;

  const VenueDetailsView({
    super.key,
    this.isFavorite,
    this.initialTab,
    required this.clubModel,
  });

  @override
  State<VenueDetailsView> createState() => _VenueDetailsViewState();
}

class _VenueDetailsViewState extends State<VenueDetailsView> {
  static const Color _bgColor = Color(0xFF0D0D0D);
  static const Color _primaryYellow = Color(0xFFDCA73A);
  static const Color _cardBgColor = Color(0xFF1A1A1A);
  static const Color _textGrey = Color(0xFFA0A0A0);

  late final String _tag;
  late final ClubDetailsController controller;

  @override
  void initState() {
    super.initState();
    _tag = widget.clubModel.id.isNotEmpty
        ? widget.clubModel.id
        : widget.clubModel.title;
    if (Get.isRegistered<ClubDetailsController>(tag: _tag)) {
      Get.delete<ClubDetailsController>(tag: _tag);
    }
    controller = Get.put(
      ClubDetailsController(
        seedClub: widget.clubModel,
        initialTab: widget.initialTab,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<ClubDetailsController>(tag: _tag)) {
      Get.delete<ClubDetailsController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      bottomNavigationBar: Obx(() {
        if (controller.isLoading.value ||
            controller.errorMessage.value != null) {
          return const SizedBox.shrink();
        }
        return ClubBottomActionBar(
          controller: controller,
          bgColor: _bgColor,
          primaryColor: _primaryYellow,
          isFavorite: widget.isFavorite,
        );
      }),
      body: RefreshIndicator(
        color: _primaryYellow,
        backgroundColor: const Color(0xFF161616),
        onRefresh: () => controller.loadDetails(showLoading: false),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels <
                notification.metrics.maxScrollExtent - 200) {
              return false;
            }
            final tabs = controller.tabs;
            if (tabs.isEmpty) return false;
            final index = controller.selectedTabIndex.value;
            if (index < 0 || index >= tabs.length) return false;
            if (tabs[index] == 'Reviews') controller.loadMoreReviews();
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              Obx(
                () => ClubSliverAppBar(
                  imageUrl: controller.clubModel.image,
                  bgColor: _bgColor,
                  onRefresh: () => controller.loadDetails(showLoading: false),
                  onShare: (origin) => DeepLinkService.instance.share(
                    controller.clubModel,
                    origin: origin,
                  ),
                ),
              ),
          Obx(() {
            if (controller.isLoading.value) {
              return const SliverToBoxAdapter(child: _DetailsShimmer());
            }
            if (controller.errorMessage.value != null) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _ErrorCard(
                    message: controller.errorMessage.value!,
                    onRetry: controller.loadDetails,
                  ),
                ),
              );
            }
            return SliverToBoxAdapter(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderSection(controller: controller),
                      const SizedBox(height: 14),
                      Obx(() {
                        final organizer = controller.organizer.value;
                        if (organizer == null) {
                          if (!controller.isClub) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            width: double.infinity, padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: _cardBgColor, borderRadius: BorderRadius.circular(16)),
                            child: const Text('Club information unavailable', style: TextStyle(color: _textGrey, fontSize: 13)),
                          );
                        }
                        return ClubFollowCard(
                          key: ValueKey(organizer['id']), club: organizer,
                          openDetails: !controller.isClub,
                          onReturn: controller.loadDetails,
                        );
                      }),
                      if (controller.isClub) ...[
                        WaitingListPanel(clubId: controller.seedClub.id),
                      ],
                      const SizedBox(height: 24),
                      Obx(
                        () => Row(
                          children: [
                            for (
                              var index = 0;
                              index < controller.tabs.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 6),
                              Expanded(
                                child: ClubTabContent.buildTabButton(
                                  title: controller.tabs[index],
                                  isSelected:
                                      controller.selectedTabIndex.value ==
                                      index,
                                  onTap: () => controller.changeTab(index),
                                  primaryColor: _primaryYellow,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Obx(() {
                        final tab =
                            controller.tabs[controller.selectedTabIndex.value];
                        switch (tab) {
                          case 'About':
                            return _AboutSection(controller: controller);
                          case 'Photos':
                            return controller.photos.isEmpty
                                ? CompactEmptyState.stacked(
                                    icon: Icons.photo_library_outlined,
                                    title: 'No photos yet',
                                    message: controller.isClub
                                        ? 'Club photos will appear here when added.'
                                        : 'Event photos will appear here when added.',
                                  )
                                : ClubTabContent.buildPhotosTab(
                                    controller.photos,
                                  );
                          case 'Tables':
                            return controller.tablePackages.isEmpty
                                ? const CompactEmptyState.stacked(
                                    icon: Icons.table_bar_outlined,
                                    title: 'No tables yet',
                                    message: 'Table packages will appear here when added.',
                                  )
                                : ClubTabContent.buildTablesTab(
                                    controller.tablePackages,
                                    _primaryYellow,
                                    _cardBgColor,
                                  );
                          case 'Reviews':
                            if (controller.isReviewsLoading.value &&
                                controller.reviews.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryYellow,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return controller.reviews.isEmpty
                                ? const CompactEmptyState.stacked(
                                    icon: Icons.reviews_outlined,
                                    title: 'No reviews yet',
                                    message: 'Guest reviews will appear here.',
                                  )
                                : ClubTabContent.buildReviewsTab(
                                    controller.reviews.toList(growable: false),
                                    _primaryYellow,
                                    _textGrey,
                                    isLoadingMore:
                                        controller.isReviewsLoadingMore.value,
                                    onLoadMore: controller.reviewsHasMore.value
                                        ? controller.loadMoreReviews
                                        : null,
                                  );
                          default:
                            return const SizedBox.shrink();
                        }
                      }),
                      if (controller.isClub) ...[
                        ClubRemoteSection(
                          clubId: controller.seedClub.id,
                          kind: 'upcoming',
                          title: 'Upcoming events',
                        ),
                        ClubRemoteSection(
                          clubId: controller.seedClub.id,
                          kind: 'past',
                          title: 'Past events',
                        ),
                        ClubRemoteSection(
                          clubId: controller.seedClub.id,
                          kind: 'artists',
                          title: "They’ve played here",
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.controller});

  final ClubDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final club = controller.clubModel;
      final detail = controller.detail.value;
      final apiRating = controller.averageRating.value;
      final rating = apiRating != null && apiRating > 0
          ? apiRating.toStringAsFixed(1)
          : club.rating;
      final reviews = controller.reviewsTotal.value ?? detail?.totalReviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(label: club.type),
            if (club.isVip) const _Badge(label: 'VIP', accent: true),
            if (detail?.isRecurring == true) const _Badge(label: 'Recurring'),
            ...?detail?.musicGenres.map((genre) => _Badge(label: genre)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomText(
                text: club.title,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (rating.isNotEmpty) ...[
              const SizedBox(width: 8),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFDCA73A), size: 18),
                  const SizedBox(width: 4),
                  CustomText(
                    text: rating,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  if (reviews != null)
                    CustomText(
                      text: ' ($reviews)',
                      fontSize: 14,
                      color: const Color(0xFFA0A0A0),
                    ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.location_on_outlined,
                size: 17,
                color: Color(0xFFA0A0A0),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AddressFromCoordinates(
                lat: club.latitude,
                lng: club.longitude,
                existingAddress: club.location,
                color: const Color(0xFFA0A0A0),
                fontSize: 13,
                maxLine: 3,
              ),
            ),
          ],
        ),
        if (club.price.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              CustomText(
                text: controller.isClub ||
                        (controller.detail.value?.hasMultipleTicketPrices ??
                            false)
                    ? 'From ${club.price}'
                    : club.price,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDCA73A),
              ),
              if (!controller.isClub)
                const CustomText(
                  text: ' /person',
                  fontSize: 14,
                  color: Color(0xFFA0A0A0),
                ),
            ],
          ),
        ],
      ],
    );
    });
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.controller});

  final ClubDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final detail = controller.detail.value;
    final description = detail?.description.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: controller.isClub
              ? _ClubAboutDetails(controller: controller)
              : _EventAboutDetails(controller: controller),
        ),
        if (!controller.isClub &&
            (detail?.ticketTiers.isNotEmpty ?? false)) ...[
          const SizedBox(height: 24),
          const CustomText(
            text: 'Tickets',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 12),
          _EventTicketTiers(tiers: detail!.ticketTiers),
        ],
        if (!controller.isClub && detail != null)
          EventCommerceSection(controller: controller, detail: detail),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 24),
          ClubTabContent.buildAboutTab(
            const Color(0xFFA0A0A0),
            description: description,
          ),
        ],
      ],
    );
  }
}

class _ClubAboutDetails extends StatelessWidget {
  const _ClubAboutDetails({required this.controller});

  final ClubDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final detail = controller.detail.value;
    final hours = [...(detail?.openingHours ?? const [])]
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(
          label: 'Dress code',
          value: detail?.dressCode.trim().isNotEmpty == true
              ? detail!.dressCode
              : '--',
        ),
        const Divider(height: 25, color: Colors.white10),
        _DetailRow(
          label: 'Recurring',
          value: detail?.isRecurring == true ? 'Yes' : 'No',
        ),
        const Divider(height: 25, color: Colors.white10),
        _DetailRow(
          label: 'VIP club',
          value: detail?.isVip == true ? 'Yes' : 'No',
        ),
        if (hours.isNotEmpty) ...[
          const SizedBox(height: 22),
          const CustomText(
            text: 'Opening Hours',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 12),
          ...hours.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DetailRow(
                label: controller.dayLabel(item.dayOfWeek),
                value: controller.formatOpeningHour(item),
                labelWidth: 108,
                singleLine: true,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EventAboutDetails extends StatelessWidget {
  const _EventAboutDetails({required this.controller});

  final ClubDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final detail = controller.detail.value;
    return Column(
      children: [
        _DetailRow(
          label: 'Status',
          value: controller.statusLabel(detail?.eventStatus),
        ),
        const Divider(height: 25, color: Colors.white10),
        _DetailRow(
          label: 'Starts',
          value: controller.formatDateTime(detail?.startAt),
        ),
        const Divider(height: 25, color: Colors.white10),
        _DetailRow(
          label: 'Ends',
          value: controller.formatDateTime(detail?.endAt),
        ),
        const Divider(height: 25, color: Colors.white10),
        _DetailRow(
          label: 'Dress code',
          value: detail?.dressCode.trim().isNotEmpty == true
              ? detail!.dressCode
              : '--',
        ),
        const Divider(height: 25, color: Colors.white10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 92,
              child: CustomText(
                text: 'Venue',
                color: Color(0xFFA0A0A0),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AddressFromCoordinates(
                lat: controller.clubModel.latitude,
                lng: controller.clubModel.longitude,
                existingAddress: controller.clubModel.location,
                color: Colors.white,
                fontSize: 13,
                maxLine: 3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventTicketTiers extends StatelessWidget {
  const _EventTicketTiers({required this.tiers});

  final List<EventTicketTierModel> tiers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var index = 0; index < tiers.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: Colors.white10),
            _EventTicketTierTree(tier: tiers[index]),
          ],
        ],
      ),
    );
  }
}

class _EventTicketTierTree extends StatelessWidget {
  const _EventTicketTierTree({required this.tier, this.depth = 0});

  final EventTicketTierModel tier;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0),
      child: Column(
        children: [
          _EventTicketTierRow(tier: tier),
          for (final child in tier.children)
            _EventTicketTierTree(tier: child, depth: depth + 1),
        ],
      ),
    );
  }
}

class _EventTicketTierRow extends StatelessWidget {
  const _EventTicketTierRow({required this.tier});

  final EventTicketTierModel tier;

  @override
  Widget build(BuildContext context) {
    final price = tier.price == tier.price.roundToDouble()
        ? tier.price.toInt().toString()
        : tier.price.toStringAsFixed(2);
    final remaining = tier.remainingCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: tier.tierName,
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                if (tier.groupName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  CustomText(
                    text: tier.groupName,
                    color: const Color(0xFFA0A0A0),
                    fontSize: 12,
                  ),
                ],
                if (!tier.isSoldOut && remaining > 0) ...[
                  const SizedBox(height: 4),
                  CustomText(
                    text: '$remaining left',
                    color: const Color(0xFFA0A0A0),
                    fontSize: 12,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CustomText(
                text: '€$price',
                color: const Color(0xFFDCA73A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              if (tier.isSoldOut) ...[
                const SizedBox(height: 3),
                const CustomText(
                  text: 'Sold out',
                  color: Color(0xFFDCA73A),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.labelWidth = 92,
    this.singleLine = false,
  });

  final String label;
  final String value;
  final double labelWidth;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: CustomText(
            text: label,
            color: const Color(0xFFA0A0A0),
            fontSize: 13,
            maxLine: singleLine ? 1 : null,
            overflow: singleLine ? TextOverflow.ellipsis : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomText(
            text: value,
            color: Colors.white,
            fontSize: 13,
            textAlign: TextAlign.right,
            maxLine: singleLine ? 1 : null,
            overflow: singleLine ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFDCA73A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: accent
            ? primary.withValues(alpha: 0.16)
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: accent ? Border.all(color: primary) : null,
      ),
      child: CustomText(
        text: label,
        color: accent ? primary : Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CustomText(
            text: 'Could not load details',
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          CustomText(text: message, color: Colors.white70, fontSize: 13),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(color: Color(0xFFDCA73A)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsShimmer extends StatelessWidget {
  const _DetailsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF171717),
      highlightColor: const Color(0xFF302719),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBox(width: 58, height: 28, radius: 18),
            SizedBox(height: 16),
            _ShimmerBox(width: 220, height: 28),
            SizedBox(height: 12),
            _ShimmerBox(width: 275, height: 15),
            SizedBox(height: 12),
            _ShimmerBox(width: 110, height: 20),
            SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: _ShimmerBox(height: 42, radius: 22)),
                SizedBox(width: 8),
                Expanded(child: _ShimmerBox(height: 42, radius: 22)),
                SizedBox(width: 8),
                Expanded(child: _ShimmerBox(height: 42, radius: 22)),
                SizedBox(width: 8),
                Expanded(child: _ShimmerBox(height: 42, radius: 22)),
              ],
            ),
            SizedBox(height: 24),
            _ShimmerBox(height: 190, radius: 16),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
