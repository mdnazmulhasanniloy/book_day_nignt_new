import 'package:bookdianight_app/app/modules/notification/controller/notification_controller.dart';
import 'package:bookdianight_app/app/modules/notification/views/notification_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../profile/controllers/profile_controller.dart';
import '../../earning/views/payment_overview_view.dart';
import '../../stripe_connect/widgets/payout_setup_banner.dart';
import '../controllers/owner_home_controller.dart';
import '../repository/owner_stats_repository.dart';
import '../widget/oeverview_card_widget.dart';
import '../widget/owner_shimmer.dart';
import '../widget/recent_booking_card_widget.dart';
import '../widget/recent_payment_card_widget.dart';

class OwnerHomeView extends StatelessWidget {
  const OwnerHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final OwnerHomeController controller = Get.put(OwnerHomeController());
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    final notifications = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController());
    const Color bgColor = Color(0xFF0D0D0D);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE1B144),
          backgroundColor: const Color(0xFF161616),
          onRefresh: () => Future.wait([
            controller.load(),
            notifications.fetch(refresh: true),
          ]),
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Section
              _buildHeader(profileController, notifications),
              const SizedBox(height: 24),
              const PayoutSetupBanner(),

              // 2. Today's Overview Section
              const CustomText(
                text: "Today's Overview",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.isLoading.value && controller.overview.isEmpty) {
                  return const OwnerOverviewGridShimmer();
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 124,
                  ),
                  itemCount: controller.overview.length,
                  itemBuilder: (context, index) {
                    final data = controller.overview[index];
                    return OverviewCardWidget(
                      icon: data.icon,
                      value: data.value,
                      label: data.label,
                    );
                  },
                );
              }),
              const SizedBox(height: 24),
              const CustomText(
                text: "Recent Bookings",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.isLoading.value &&
                    controller.recentBookings.isEmpty) {
                  return const OwnerBookingListShimmer();
                }
                if (controller.recentBookings.isEmpty) {
                  return const CompactEmptyState(
                    icon: Icons.event_seat_outlined,
                    title: 'No recent bookings',
                    message: 'New bookings will appear here.',
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.recentBookings.length,
                  itemBuilder: (context, index) {
                    final booking = controller.recentBookings[index];
                    return RecentBookingCardWidget(
                      imageUrl: booking.thumbnail,
                      title: booking.name,
                      location: booking.location,
                      latitude: booking.latitude,
                      longitude: booking.longitude,
                      tags: _bookingTags(booking),
                    );
                  },
                );
              }),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CustomText(
                    text: 'Recent Payments',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  GestureDetector(
                    onTap: () => Get.to(() => const PaymentOverviewView()),
                    child: const Row(
                      children: [
                        CustomText(
                          text: 'See all',
                          fontSize: 12,
                          color: Color(0xFFE1B144),
                          fontWeight: FontWeight.w500,
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Color(0xFFE1B144),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.isLoading.value &&
                    controller.recentPayments.isEmpty) {
                  return const OwnerPaymentListShimmer();
                }
                if (controller.recentPayments.isEmpty) {
                  return const CompactEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No payments yet',
                    message: 'Payments from bookings will appear here.',
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.recentPayments.length,
                  itemBuilder: (context, index) {
                    final payment = controller.recentPayments[index];
                    return RecentPaymentCardWidget(
                      title: payment.title,
                      subtitle: payment.subtitle,
                      amount: payment.amountLabel,
                      onTap: () => showOwnerPaymentDialog(payment),
                    );
                  },
                );
              }),
              const SizedBox(height: 80),
            ],
          ),
        ),
        ),
      ),
    );
  }

  List<String> _bookingTags(OwnerRecentBooking booking) {
    final tags = <String>[booking.isEvent ? 'Event' : 'Club'];
    if (booking.isVip) tags.add('VIP');
    if (!booking.isEvent) {
      final review = booking.review ?? 0;
      tags.add(review == 0 ? '0' : review.toStringAsFixed(1));
    }
    if (booking.minPrice != null) {
      tags.add('From ${formatOwnerEuro(booking.minPrice!)}');
    }
    return tags;
  }

  Widget _buildHeader(
    ProfileController profileController,
    NotificationController notifications,
  ) {
    return Obx(() {
      final isInitialLoading =
          profileController.isLoading.value &&
          profileController.userModel.value == null;

      return Row(
        children: [
          if (isInitialLoading)
            const _ProfileAvatarShimmer()
          else
            _ProfileAvatar(imageUrl: profileController.userAvatar.value),
          const SizedBox(width: 12),
          Expanded(
            child: isInitialLoading
                ? const _ProfileNameShimmer()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CustomText(
                        text: 'Good Evening,',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      CustomText(
                        text: profileController.userName.value.trim().isEmpty
                            ? 'Club Owner'
                            : profileController.userName.value.trim(),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => Get.to(() => const NotificationView()),
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Obx(() {
                    notifications.notifications.length;
                    final badge = notifications.badgeLabel;
                    if (badge.isEmpty) return const SizedBox.shrink();
                    return Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1B144),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0D0D0D),
                          width: 1.5,
                        ),
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
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        height: 48,
        width: 48,
        decoration: const BoxDecoration(
          color: Color(0xFF202020),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 24),
      );
    }

    return CustomNetworkImage(
      imageUrl: imageUrl,
      height: 48,
      width: 48,
      boxShape: BoxShape.circle,
    );
  }
}

class _ProfileAvatarShimmer extends StatelessWidget {
  const _ProfileAvatarShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF202020),
      highlightColor: const Color(0xFF353535),
      child: Container(
        height: 48,
        width: 48,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ProfileNameShimmer extends StatelessWidget {
  const _ProfileNameShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF202020),
      highlightColor: const Color(0xFF353535),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 10,
            width: 82,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 15,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
