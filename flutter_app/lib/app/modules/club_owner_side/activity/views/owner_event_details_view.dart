import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/explore/model/event_offer_model.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../user_side/club_details_view/widgets/club_sliver_app_bar.dart';
import '../../../user_side/club_details_view/widgets/club_tab_content.dart';
import '../../../user_side/club_details_view/widgets/club_community_section.dart';
import '../controllers/owner_activity_controller.dart';
import 'edit_event_view.dart';
import 'owner_event_ops_view.dart';

class OwnerEventDetailsView extends StatefulWidget {
  const OwnerEventDetailsView({super.key, required this.item});

  final ActivityItemModel item;

  @override
  State<OwnerEventDetailsView> createState() => _OwnerEventDetailsViewState();
}

class _OwnerEventDetailsViewState extends State<OwnerEventDetailsView> {
  static const _background = Color(0xFF0D0D0D);
  static const _cardColor = Color(0xFF1A1A1A);
  static const _primary = Color(0xFFDCA73A);
  static const _textGrey = Color(0xFFA0A0A0);

  final selectedTabIndex = 0.obs;
  late ActivityItemModel _item;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  Future<void> _loadDetails({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final controller = Get.find<OwnerActivityController>();
      final details = await controller.getActivityDetails(_item);
      if (!mounted) return;
      setState(() {
        _item = details;
        _error = null;
      });
      controller.updateActivityItem(details);
    } catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      if (showSpinner) {
        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDetails() => _loadDetails(showSpinner: false);

  Future<void> _editEvent() async {
    final result = await Get.to(() => EditEventView(item: _item));
    if (result != null && mounted) await _refreshDetails();
  }

  List<String> get _photos => <String>{
    if (_item.image.trim().isNotEmpty) _item.image,
    ..._item.images.where((image) => image.trim().isNotEmpty),
  }.toList(growable: false);

  @override
  Widget build(BuildContext context) {
    const tabs = ['About', 'Photos'];
    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: SizedBox(
                  height: 52,
                  child: CustomButton(
                    title: 'Edit Event',
                    isGradient: false,
                    buttonColor: _primary,
                    titleColor: Colors.black,
                    paddingVertical: 0,
                    borderRadius: 16,
                    onTap: _editEvent,
                  ),
                ),
              ),
            ),
      body: RefreshIndicator(
        color: _primary,
        backgroundColor: _cardColor,
        onRefresh: _refreshDetails,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          ClubSliverAppBar(
            imageUrl: _item.image,
            bgColor: _background,
            onRefresh: _refreshDetails,
          ),
          if (_isLoading)
            const SliverToBoxAdapter(child: _EventDetailsShimmer()),
          if (!_isLoading && _error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildError(),
              ),
            ),
          if (!_isLoading && _error == null)
            SliverToBoxAdapter(
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      Obx(
                        () => Row(
                          children: List.generate(tabs.length, (index) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == tabs.length - 1 ? 0 : 8,
                                ),
                                child: ClubTabContent.buildTabButton(
                                  title: tabs[index],
                                  isSelected: selectedTabIndex.value == index,
                                  onTap: () => selectedTabIndex.value = index,
                                  primaryColor: _primary,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Obx(() {
                        final tabIndex = selectedTabIndex.value
                            .clamp(0, tabs.length - 1);
                        switch (tabs[tabIndex]) {
                          case 'About':
                            return _buildAbout();
                          case 'Photos':
                            return _photos.isEmpty
                                ? const CompactEmptyState.stacked(
                                    icon: Icons.photo_library_outlined,
                                    title: 'No photos yet',
                                    message: 'Event photos will appear here when added.',
                                  )
                                : ClubTabContent.buildPhotosTab(_photos);
                          default:
                            return const SizedBox.shrink();
                        }
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _clubLabel {
    if (_item.clubName.trim().isNotEmpty) return _item.clubName.trim();
    final clubId = _item.clubId?.trim() ?? '';
    if (clubId.isEmpty || !Get.isRegistered<OwnerActivityController>()) {
      return '';
    }
    for (final item in Get.find<OwnerActivityController>().activityList) {
      if (item.type.toUpperCase() == 'CLUB' && item.id == clubId) {
        return item.title;
      }
    }
    return '';
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CustomText(
                text: 'Event',
                color: Colors.white,
                fontSize: 11,
              ),
            ),
            for (final genre in _item.musicGenres)
              if (genre.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CustomText(
                    text: genre.trim(),
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
          ],
        ),
        const SizedBox(height: 14),
        CustomText(
          text: _item.title,
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        if (_item.bookingsClosed) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF261D0A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withValues(alpha: 0.4)),
            ),
            child: const CustomText(
              text: 'Bookings closed',
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_item.location.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: _textGrey,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CustomText(
                  text: _item.location,
                  color: _textGrey,
                  fontSize: 13,
                  maxLine: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        CustomText(
          text: _item.price,
          color: _primary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }

  Widget _buildAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _detailRow('Activity', _item.isActive ? 'Active' : 'Inactive'),
              if (!_item.isActive && _item.deactivatedAt != null) ...[
                const Divider(height: 25, color: Colors.white10),
                _detailRow('Deactivated', _dateTimeLabel(_item.deactivatedAt)),
              ],
              const Divider(height: 25, color: Colors.white10),
              _detailRow(
                'Status',
                _statusLabel(_item.eventStatus ?? _item.status),
              ),
              const Divider(height: 25, color: Colors.white10),
              _detailRow(
                'Bookings',
                _item.bookingsClosed ? 'Closed' : 'Open',
              ),
              const Divider(height: 25, color: Colors.white10),
              _detailRow('Starts at', _dateTimeLabel(_item.startAt)),
              const Divider(height: 25, color: Colors.white10),
              _detailRow('Ends at', _dateTimeLabel(_item.endAt)),
              const Divider(height: 25, color: Colors.white10),
              _detailRow('Dress code', _item.dressCode),
              if (_clubLabel.isNotEmpty) ...[
                const Divider(height: 25, color: Colors.white10),
                _detailRow('Club', _clubLabel),
              ],
              if (_item.hostIds.isNotEmpty) ...[
                const Divider(height: 25, color: Colors.white10),
                _detailRow(
                  'Hosts',
                  '${_item.hostIds.length} assigned',
                ),
              ],
            ],
          ),
        ),
        if (_item.ticketTiers.isNotEmpty) ...[
          const SizedBox(height: 24),
          const CustomText(
            text: 'Ticket tiers',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          _OwnerTicketTiers(tiers: _item.ticketTiers),
        ],
        if (_item.lineup.isNotEmpty) ...[
          const SizedBox(height: 24),
          const CustomText(
            text: 'Lineup',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: EventLineupRows(artists: _item.lineup),
          ),
        ],
        const SizedBox(height: 24),
        OwnerEventOpsTiles(
          eventId: _item.id,
          eventName: _item.title,
          startAt: _item.startAt,
          endAt: _item.endAt,
          bookingsClosed: _item.bookingsClosed,
          hostIds: _item.hostIds,
          onOpsChanged: _refreshDetails,
          onBookingsClosed: (closed) {
            setState(() => _item.bookingsClosed = closed);
            if (Get.isRegistered<OwnerActivityController>()) {
              Get.find<OwnerActivityController>().updateActivityItem(_item);
            }
          },
          onHostAssigned: (hostId) {
            if (_item.hostIds.contains(hostId)) return;
            setState(() => _item.hostIds = [..._item.hostIds, hostId]);
            if (Get.isRegistered<OwnerActivityController>()) {
              Get.find<OwnerActivityController>().updateActivityItem(_item);
            }
          },
          onHostUnassigned: (hostId) {
            if (!_item.hostIds.contains(hostId)) return;
            setState(
              () => _item.hostIds =
                  _item.hostIds.where((id) => id != hostId).toList(),
            );
            if (Get.isRegistered<OwnerActivityController>()) {
              Get.find<OwnerActivityController>().updateActivityItem(_item);
            }
          },
        ),
        if (_item.description.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          ClubTabContent.buildAboutTab(
            _textGrey,
            description: _item.description,
          ),
        ],
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: CustomText(text: label, color: _textGrey, fontSize: 13),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomText(
            text: value,
            color: Colors.white,
            fontSize: 13,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _dateTimeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}, $hour:$minute $period';
  }

  String _statusLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: CustomText(
              text: _error ?? '',
              color: Colors.white70,
              fontSize: 12,
              maxLine: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => _loadDetails(),
            child: const CustomText(
              text: 'Retry',
              color: _primary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerTicketTiers extends StatelessWidget {
  const _OwnerTicketTiers({required this.tiers});

  final List<EventTicketTierModel> tiers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < tiers.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: Colors.white10),
            _OwnerTicketTierTree(tier: tiers[index]),
          ],
        ],
      ),
    );
  }
}

class _OwnerTicketTierTree extends StatelessWidget {
  const _OwnerTicketTierTree({required this.tier, this.depth = 0});

  final EventTicketTierModel tier;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0),
      child: Column(
        children: [
          _OwnerTicketTierRow(tier: tier),
          for (final child in tier.children)
            _OwnerTicketTierTree(tier: child, depth: depth + 1),
        ],
      ),
    );
  }
}

class _OwnerTicketTierRow extends StatelessWidget {
  const _OwnerTicketTierRow({required this.tier});

  final EventTicketTierModel tier;

  @override
  Widget build(BuildContext context) {
    final price = tier.price == tier.price.roundToDouble()
        ? tier.price.toInt().toString()
        : tier.price.toStringAsFixed(2);
    final status = !tier.isActive
        ? 'Disabled'
        : tier.isSoldOut
        ? 'Sold out'
        : '${tier.remainingCount} left';
    final statusColor = !tier.isActive || tier.isSoldOut
        ? const Color(0xFF8A8A8A)
        : const Color(0xFFDCA73A);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  maxLine: 2,
                  overflow: TextOverflow.ellipsis,
                  height: 1.3,
                ),
                if (tier.groupName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  CustomText(
                    text: tier.groupName,
                    color: const Color(0xFFA0A0A0),
                    fontSize: 12,
                    maxLine: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CustomText(
                text: '€$price',
                color: const Color(0xFFDCA73A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CustomText(
                  text: status,
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventDetailsShimmer extends StatelessWidget {
  const _EventDetailsShimmer();

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
            _EventShimmerBox(width: 58, height: 28, radius: 18),
            SizedBox(height: 16),
            _EventShimmerBox(width: 220, height: 28),
            SizedBox(height: 12),
            _EventShimmerBox(width: 275, height: 15),
            SizedBox(height: 12),
            _EventShimmerBox(width: 110, height: 20),
            SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: _EventShimmerBox(height: 42, radius: 22)),
                SizedBox(width: 8),
                Expanded(child: _EventShimmerBox(height: 42, radius: 22)),
                SizedBox(width: 8),
                Expanded(child: _EventShimmerBox(height: 42, radius: 22)),
              ],
            ),
            SizedBox(height: 24),
            _EventShimmerBox(height: 190, radius: 16),
          ],
        ),
      ),
    );
  }
}

class _EventShimmerBox extends StatelessWidget {
  const _EventShimmerBox({
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
