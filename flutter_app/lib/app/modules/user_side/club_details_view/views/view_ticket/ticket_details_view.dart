import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:barcode_widget/barcode_widget.dart';

import '../../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../../dashboard/user_dashboard.dart';
import '../../../home/controllers/club_controller.dart';
import '../../controllers/buy_ticker_controller.dart';

class TicketDetailsView extends StatelessWidget {
  final ClubModel? clubModel;
  final bool isClub;

  const TicketDetailsView({
    super.key,
    this.clubModel,
    this.isClub = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<BuyTickerController>()
        ? Get.find<BuyTickerController>()
        : Get.put(BuyTickerController());

    const Color bgColor = Color(0xFF0D0D0D);
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);

    final ClubModel effectiveClub = clubModel ??
        ClubModel(
          title: isClub ? 'Sky Garden Rooftop' : 'XOYO London',
          type: isClub ? 'club' : 'event',
          image: isClub
              ? 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819'
              : 'https://images.unsplash.com/photo-1540039155732-d688d52cb4b1',
          price: isClub ? 'From €65' : '€191.00',
          rating: '4.8',
          location: isClub ? 'Farringdon, EC1' : 'Shoreditch',
        );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Get.offAll(() => const UserDashboard());
      },
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: CustomAppBar(
        title: isClub ? 'Reservation Details' : 'Ticket Details',
        backgroundColor: bgColor,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: CustomButton(
                title: 'Go to Dashboard',
                buttonColor: primaryYellow,
                isGradient: false,
                borderRadius: 16,
                paddingVertical: 14,
                onTap: () => Get.offAll(() => const UserDashboard()),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomNetworkImage(
                imageUrl: effectiveClub.image,
                height: 220,
                width: double.infinity,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: effectiveClub.title,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    Obx(() {
                      final orderId = controller.confirmedOrderId.value.trim();
                      if (orderId.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                height: 180,
                                width: 180,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: BarcodeWidget(
                                  barcode: Barcode.qrCode(),
                                  data: orderId,
                                  color: Colors.black,
                                  drawText: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const CustomText(
                              text: 'Scan this code at the door',
                              fontSize: 12,
                              color: Colors.grey,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoColumn(
                            'Date',
                            isClub
                                ? controller.clubDateSummary
                                : controller.eventDateLabel,
                            CrossAxisAlignment.start,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoColumn(
                            'Time',
                            isClub
                                ? controller.clubTimeSummary
                                : controller.eventTimeLabel,
                            CrossAxisAlignment.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildInfoColumn(
                            'Place',
                            effectiveClub.location.trim().isEmpty
                                ? 'Not available'
                                : effectiveClub.location.trim(),
                            CrossAxisAlignment.start,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _buildInfoColumn(
                            isClub ? 'Guest' : 'Attendees',
                            isClub
                                ? (controller.selectedPackage['capacity'] ??
                                      '2-10 guests')
                                : '${controller.guestCount.value} Tickets',
                            CrossAxisAlignment.end,
                            valueColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    String value,
    CrossAxisAlignment alignment, {
    Color valueColor = Colors.white70,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        CustomText(text: label, fontSize: 12, color: Colors.grey),
        const SizedBox(height: 4),
        CustomText(
          text: value,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: valueColor,
          maxLine: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: alignment == CrossAxisAlignment.end
              ? TextAlign.end
              : TextAlign.start,
        ),
      ],
    );
  }
}
