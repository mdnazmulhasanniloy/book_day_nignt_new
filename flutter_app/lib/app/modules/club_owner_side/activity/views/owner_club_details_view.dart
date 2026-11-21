import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../user_side/club_details_view/model/club_review_model.dart';
import '../../../user_side/club_details_view/widgets/club_sliver_app_bar.dart';
import '../../../user_side/club_details_view/widgets/club_tab_content.dart';
import '../controllers/owner_activity_controller.dart';
import 'edit_club_view.dart';
import 'edit_event_view.dart';
import 'owner_waiting_list_view.dart';

class OwnerClubDetailsView extends StatefulWidget {
  final ActivityItemModel item;

  const OwnerClubDetailsView({super.key, required this.item});

  @override
  State<OwnerClubDetailsView> createState() => _OwnerClubDetailsViewState();
}

class _OwnerClubDetailsViewState extends State<OwnerClubDetailsView> {
  var selectedTabIndex = 0.obs;
  late ActivityItemModel _item;
  bool _isLoadingDetails = true;
  String? _detailsError;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  Future<void> _loadDetails() async {
    final controller = Get.find<OwnerActivityController>();
    setState(() {
      _isLoadingDetails = true;
      _detailsError = null;
    });
    try {
      final details = await controller.getActivityDetails(_item);
      if (!mounted) return;
      setState(() {
        _item = details;
      });
      controller.updateActivityItem(details);
    } catch (error) {
      if (mounted) {
        setState(() {
          _detailsError = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  List<String> get _photos {
    return <String>{
      if (_item.image.trim().isNotEmpty) _item.image,
      ..._item.images.where((image) => image.trim().isNotEmpty),
    }.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    bool isClub = _item.type.toLowerCase() == 'club';

    final tabs = isClub
        ? ['About', 'Photos', 'Tables', 'Reviews']
        : ['About', 'Photos', 'Reviews'];

    const Color bgColor = Color(0xFF0D0D0D);
    const Color primaryYellow = Color(0xFFDCA73A);
    const Color cardBgColor = Color(0xFF1A1A1A);
    const Color textGrey = Color(0xFFA0A0A0);

    return Scaffold(
      backgroundColor: bgColor,

      // Owner Specific Bottom Action Bar with Fixed Height Constraints
      bottomNavigationBar: _isLoadingDetails || _detailsError != null
          ? null
          : SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isClub) ...[
                          Expanded(
                            child: CustomButton(
                              title: 'Waiting list',
                              isGradient: false,
                              buttonColor: Colors.transparent,
                              border: Border.all(color: primaryYellow),
                              titleColor: primaryYellow,
                              paddingVertical: 14,
                              borderRadius: 16,
                              onTap: () {
                                Get.to(
                                  () => OwnerWaitingListView(
                                    clubId: _item.id,
                                    clubName: _item.title,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: CustomButton(
                            title: isClub ? 'Edit Club' : 'Edit Event',
                            isGradient: false,
                            buttonColor: primaryYellow,
                            titleColor: Colors.black,
                            paddingVertical: 14,
                            borderRadius: 16,
                            onTap: () async {
                              if (isClub) {
                                final result = await Get.to(
                                  () => EditClubView(item: _item),
                                );
                                if (result != null && mounted) {
                                  await _loadDetails();
                                }
                              } else {
                                Get.to(() => EditEventView(item: _item));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      body: RefreshIndicator(
        color: primaryYellow,
        backgroundColor: const Color(0xFF161616),
        onRefresh: _loadDetails,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Cover Image
            ClubSliverAppBar(
              imageUrl: _item.image,
              bgColor: bgColor,
              onRefresh: _loadDetails,
            ),

          if (_isLoadingDetails)
            const SliverToBoxAdapter(child: _OwnerClubDetailsShimmer()),

          if (!_isLoadingDetails && _detailsError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildErrorCard(primaryYellow),
              ),
            ),

          if (!_isLoadingDetails && _detailsError == null)
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
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderInfo(primaryYellow, textGrey),
                      const SizedBox(height: 24),

                      Obx(
                        () => Row(
                          children: [
                            for (
                              var index = 0;
                              index < tabs.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 6),
                              Expanded(
                                child: ClubTabContent.buildTabButton(
                                  title: tabs[index],
                                  isSelected: selectedTabIndex.value == index,
                                  onTap: () => selectedTabIndex.value = index,
                                  primaryColor: primaryYellow,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Obx(() {
                        String currentTab = tabs[selectedTabIndex.value];
                        switch (currentTab) {
                          case 'About':
                            return _buildAboutTab(cardBgColor, textGrey);
                          case 'Photos':
                            return _photos.isEmpty
                                ? const CompactEmptyState.stacked(
                                    icon: Icons.photo_library_outlined,
                                    title: 'No photos yet',
                                    message: 'Club photos will appear here when added.',
                                  )
                                : ClubTabContent.buildPhotosTab(_photos);
                          case 'Tables':
                            return _buildPackagesTab(
                              primaryYellow,
                              cardBgColor,
                              textGrey,
                            );
                          case 'Reviews':
                            return ClubTabContent.buildReviewsTab(
                              [
                                ClubReviewModel(
                                  id: '',
                                  rating: 5,
                                  review:
                                      'I highly recommend this club for a great night out. The atmosphere and service were excellent.',
                                  createdAt: DateTime(2026, 2, 6),
                                  reviewerName: 'Annisa Azalea',
                                  reviewerAvatar: '',
                                ),
                              ],
                              primaryYellow,
                              textGrey,
                            );
                          default:
                            return const SizedBox.shrink();
                        }
                      }),
                      const SizedBox(height: 40),
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

  Widget _buildHeaderInfo(Color primary, Color textGrey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBadge(_item.type),
            if (_item.isVip) _buildBadge('VIP', color: primary),
            if (_item.isRecurring) _buildBadge('Recurring'),
          ],
        ),
        const SizedBox(height: 14),
        CustomText(
          text: _item.title,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        const SizedBox(height: 8),
        if (_item.location.trim().isNotEmpty)
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
                child: CustomText(
                  text: _item.location,
                  fontSize: 13,
                  color: textGrey,
                  maxLine: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (_item.price != '--') ...[
          const SizedBox(height: 10),
          CustomText(
            text: _item.price,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.16) ?? const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: color == null ? null : Border.all(color: color),
      ),
      child: CustomText(
        text: label,
        color: color ?? Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAboutTab(Color cardColor, Color textGrey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailsTab(cardColor, textGrey),
        if (_item.description.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          ClubTabContent.buildAboutTab(
            textGrey,
            description: _item.description,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsTab(Color cardColor, Color textGrey) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            'Activity',
            _item.isActive ? 'Active' : 'Inactive',
            textGrey,
          ),
          if (!_item.isActive && _item.deactivatedAt != null) ...[
            const Divider(height: 25, color: Colors.white10),
            _buildDetailRow(
              'Deactivated',
              _dateTimeLabel(_item.deactivatedAt!),
              textGrey,
            ),
          ],
          const Divider(height: 25, color: Colors.white10),
          _buildDetailRow('Dress code', _item.dressCode, textGrey),
          const Divider(height: 25, color: Colors.white10),
          _buildDetailRow(
            'Recurring',
            _item.isRecurring ? 'Yes' : 'No',
            textGrey,
          ),
          const Divider(height: 25, color: Colors.white10),
          _buildDetailRow('VIP club', _item.isVip ? 'Yes' : 'No', textGrey),
          const SizedBox(height: 22),
          const CustomText(
            text: 'Opening Hours',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 12),
          if (_item.openingHoursData.isEmpty)
            const SizedBox.shrink()
          else
            ..._buildOpeningHourRows(textGrey),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color textGrey, {
    double labelWidth = 92,
    bool singleLine = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: CustomText(
            text: label,
            color: textGrey,
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

  List<Widget> _buildOpeningHourRows(Color textGrey) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final hours = [..._item.openingHoursData]
      ..sort((first, second) => first.dayOfWeek.compareTo(second.dayOfWeek));

    return hours
        .map((item) {
          final day = item.dayOfWeek >= 0 && item.dayOfWeek < days.length
              ? days[item.dayOfWeek]
              : 'Day ${item.dayOfWeek}';
          final value = item.isClosed
              ? 'Closed'
              : '${_timeLabel(item.openTime)} – ${_timeLabel(item.closeTime)}${_closesAfterMidnight(item.openTime, item.closeTime) ? ' (+1 day)' : ''}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildDetailRow(
              day,
              value,
              textGrey,
              labelWidth: 108,
              singleLine: true,
            ),
          );
        })
        .toList(growable: false);
  }

  String _dateTimeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}, $hour:$minute $period';
  }

  String _timeLabel(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  bool _closesAfterMidnight(DateTime open, DateTime close) {
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;
    return closeMinutes <= openMinutes;
  }

  Widget _buildPackagesTab(Color primary, Color cardColor, Color textGrey) {
    if (_item.clubPackages.isEmpty) {
      return const CompactEmptyState.stacked(
        icon: Icons.table_bar_outlined,
        title: 'No tables yet',
        message: 'Table packages will appear here when added.',
      );
    }

    final packages = [..._item.clubPackages]
      ..sort((first, second) => first.sortOrder.compareTo(second.sortOrder));
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: packages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final package = packages[index];
        final price = package.price == package.price.roundToDouble()
            ? package.price.toInt().toString()
            : package.price.toStringAsFixed(2);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomText(
                      text: package.name,
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  CustomText(
                    text: '€$price',
                    color: primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              CustomText(
                text: package.description,
                color: textGrey,
                fontSize: 13,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPackageChip('${package.capacity} guests'),
                  _buildPackageChip(package.isActive ? 'Active' : 'Inactive'),
                ],
              ),
              if (package.features.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...package.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: primary, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomText(
                            text: feature,
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPackageChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomText(text: label, color: Colors.white70, fontSize: 11),
    );
  }

  Widget _buildErrorCard(Color primary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: CustomText(
              text: _detailsError!,
              color: Colors.white70,
              fontSize: 12,
              maxLine: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _loadDetails,
            child: CustomText(text: 'Retry', color: primary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OwnerClubDetailsShimmer extends StatelessWidget {
  const _OwnerClubDetailsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF171717),
      highlightColor: const Color(0xFF302719),
      period: const Duration(milliseconds: 1250),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _DetailsShimmerBox(width: 54, height: 28, radius: 18),
                SizedBox(width: 8),
                _DetailsShimmerBox(width: 46, height: 28, radius: 18),
                SizedBox(width: 8),
                _DetailsShimmerBox(width: 76, height: 28, radius: 18),
              ],
            ),
            const SizedBox(height: 16),
            const _DetailsShimmerBox(width: 210, height: 28),
            const SizedBox(height: 12),
            const _DetailsShimmerBox(width: 270, height: 15),
            const SizedBox(height: 26),
            Row(
              children: List.generate(
                4,
                (index) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 7),
                    child: _DetailsShimmerBox(height: 42, radius: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _DetailsShimmerBox(height: 210, radius: 16),
            const SizedBox(height: 12),
            const _DetailsShimmerBox(height: 82, radius: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailsShimmerBox extends StatelessWidget {
  const _DetailsShimmerBox({
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
