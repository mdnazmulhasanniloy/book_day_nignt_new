import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../../home/controllers/club_controller.dart';
import '../../controllers/buy_ticker_controller.dart';
import 'ticket_booking_details.dart';

class SelectPackageView extends StatelessWidget {
  final ClubModel clubModel;

  const SelectPackageView({super.key, required this.clubModel});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BuyTickerController>();
    const Color bgColor = Color(0xFF0D0D0D);
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const CustomAppBar(
        title: 'Select Package',
        backgroundColor: bgColor,
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: CustomButton(
                title: 'Continue',
                buttonColor: primaryYellow,
                isGradient: false,
                borderRadius: 16,
                paddingVertical: 14,
                onTap: () {
                  final packageId =
                      controller.selectedPackage['id']?.toString() ?? '';
                  if (packageId.isEmpty) return;
                  Get.to(() => TicketBookingDetailsView(
                        clubModel: clubModel,
                        isClub: true,
                      ));
                },
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: List.generate(
            controller.tablePackages.length,
            (index) => _buildPackageCard(
              context,
              index,
              controller.tablePackages[index],
              cardBgColor,
              primaryYellow,
              controller,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageCard(
    BuildContext context,
    int index,
    Map<String, dynamic> package,
    Color cardBgColor,
    Color primaryYellow,
    BuyTickerController controller,
  ) {
    return Obx(() {
      bool isSelected = controller.selectedPackageIndex.value == index;

      return GestureDetector(
        onTap: () => controller.selectPackage(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryYellow : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText(
                    text: package['title'],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  CustomText(
                    text: package['price'],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryYellow,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              CustomText(
                text: 'Capacity: ${package['capacity']}',
                fontSize: 12,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (package['features'] as List<String>)
                    .map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            const CustomText(
                              text: '• ',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            CustomText(
                              text: feature,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
    });
  }
}
