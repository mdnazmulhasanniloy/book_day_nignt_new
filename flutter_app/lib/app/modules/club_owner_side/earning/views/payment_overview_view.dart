import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_drop_down_widget.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../owner_home/widget/owner_shimmer.dart';
import '../../owner_home/widget/recent_payment_card_widget.dart';
import '../controllers/payment_overview_controller.dart';

class PaymentOverviewView extends StatelessWidget {
  const PaymentOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PaymentOverviewController());
    const primaryYellow = Color(0xFFE1B144);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(
        title: 'Payment Overview',
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Obx(
              () => Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF262626), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    for (final entry in const ['Club', 'Event'].indexed)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => controller.selectTab(entry.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: controller.selectedTabIndex.value ==
                                          entry.$1
                                      ? primaryYellow
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Center(
                              child: CustomText(
                                text: entry.$2,
                                fontSize: 14,
                                fontWeight:
                                    controller.selectedTabIndex.value ==
                                        entry.$1
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: controller.selectedTabIndex.value ==
                                        entry.$1
                                    ? Colors.white
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                final tab = controller.selectedTabIndex.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      if (tab == 0)
                        CustomDropDownWidget(
                          label: 'Select Club',
                          labelColor: Colors.white,
                          items: controller.clubNames,
                          selectedValue: controller.clubNames.contains(
                                controller.selectedClub.value,
                              )
                              ? controller.selectedClub.value
                              : PaymentOverviewController.allLabel,
                          hintText: 'Select Club',
                          fillColor: const Color(0xFF161616),
                          filled: true,
                          isBorder: false,
                          borderRadius: 12,
                          onChanged: (value) {
                            if (value != null) controller.selectClub(value);
                          },
                        )
                      else
                        CustomDropDownWidget(
                          label: 'Select Event',
                          labelColor: Colors.white,
                          items: controller.eventNames,
                          selectedValue: controller.eventNames.contains(
                                controller.selectedEvent.value,
                              )
                              ? controller.selectedEvent.value
                              : PaymentOverviewController.allLabel,
                          hintText: 'Select Event',
                          fillColor: const Color(0xFF161616),
                          filled: true,
                          isBorder: false,
                          borderRadius: 12,
                          onChanged: (value) {
                            if (value != null) controller.selectEvent(value);
                          },
                        ),
                      const SizedBox(height: 16),
                      Expanded(child: _PaymentList(controller: controller)),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.controller});

  final PaymentOverviewController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.payments.isEmpty) {
        return const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: OwnerPaymentListShimmer(count: 6),
        );
      }
    if (controller.payments.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: CompactEmptyState.stacked(
          icon: Icons.receipt_long_outlined,
          title: 'No payments yet',
          message: 'Payments from bookings will appear here.',
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          controller.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            controller.payments.length +
            (controller.isLoadingMore.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= controller.payments.length) {
            return const OwnerPaymentListShimmer(count: 1);
          }
          final payment = controller.payments[index];
          return RecentPaymentCardWidget(
            title: payment.title,
            subtitle: payment.subtitle,
            amount: payment.amountLabel,
            onTap: () => showOwnerPaymentDialog(payment),
          );
        },
      ),
    );
    });
  }
}
