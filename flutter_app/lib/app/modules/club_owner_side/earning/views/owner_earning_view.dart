import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../owner_home/widget/owner_shimmer.dart';
import '../../owner_home/widget/recent_payment_card_widget.dart';
import '../controllers/owner_earning_controller.dart';
import '../widget/earning_overview_card.dart';
import '../widget/monthly_earning_chart_widget.dart';
import 'payment_overview_view.dart';

class OwnerEarningView extends StatelessWidget {
  const OwnerEarningView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OwnerEarningController());
    const Color primaryYellow = Color(0xFFDCA73A);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryYellow,
          backgroundColor: const Color(0xFF161616),
          onRefresh: controller.load,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header Title
              const Center(
                child: CustomText(
                  text: "Earnings",
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Today's Overview Header
              const CustomText(
                text: "Today's Overview",
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              const SizedBox(height: 12),

              // Today's Overview 2x2 Grid
              Obx(
                () => controller.isLoading.value &&
                        controller.monthlyEarnings.isEmpty
                    ? const OwnerOverviewGridShimmer()
                    : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 124,
                  children: [
                    EarningOverviewCard(
                      icon: Icons.account_balance_wallet_outlined,
                      value: controller.todayRevenue.value,
                      title: "Today's Revenue",
                    ),
                    EarningOverviewCard(
                      icon: Icons.calendar_view_week_outlined,
                      value: controller.last7DaysRevenue.value,
                      title: 'Last 7 Days',
                    ),
                    EarningOverviewCard(
                      icon: Icons.chair_outlined,
                      value: controller.clubBookings.value,
                      title: 'Club Bookings',
                    ),
                    EarningOverviewCard(
                      icon: Icons.confirmation_number_outlined,
                      value: controller.ticketsSold.value,
                      title: 'Tickets Sold',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Monthly Earning Section
              Obx(
                () => controller.isLoading.value &&
                        controller.monthlyEarnings.isEmpty
                    ? const OwnerChartShimmer()
                    : const MonthlyEarningChartWidget(),
              ),
              const SizedBox(height: 24),

              // Payments Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CustomText(
                    text: "Payments",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  GestureDetector(
                    onTap: () {
                      Get.to(() => const PaymentOverviewView());
                    },
                    child: const Row(
                      children: [
                        CustomText(
                          text: "See all",
                          fontSize: 12,
                          color: primaryYellow,
                          fontWeight: FontWeight.w500,
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: primaryYellow,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Payments List
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

              const SizedBox(height: 100),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
