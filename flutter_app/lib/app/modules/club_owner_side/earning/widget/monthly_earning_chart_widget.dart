import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../controllers/owner_earning_controller.dart';

class MonthlyEarningChartWidget extends StatelessWidget {
  const MonthlyEarningChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OwnerEarningController>();

    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);
    const Color darkBarColor = Color(0xFF2C2C2E);
    const Color pillBgColor = Color(0xFF262628);
    const Color tooltipBgColor = Color(0xFF2B2B2D);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: "Monthly Earning",
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    SizedBox(height: 4),
                    CustomText(
                      text: "Track your earning performance over time",
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Year Dropdown Pill Only
              Obx(
                () => PopupMenuButton<String>(
                  onSelected: (val) => controller.changeYear(val),
                  color: const Color(0xFF262628),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  itemBuilder: (context) {
                    return controller.years.map((year) {
                      return PopupMenuItem<String>(
                        value: year,
                        child: CustomText(
                          text: year,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pillBgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText(
                          text: controller.selectedYear.value,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bar Chart Container
          Obx(() {
            final dataList = controller.currentYearEarnings;
            final peakIndex = controller.peakMonthIndex;

            var maxAmount = 1.0;
            for (final item in dataList) {
              if (item.amount > maxAmount) maxAmount = item.amount;
            }

            return SizedBox(
              height: 180,
              child: Column(
                children: [
                  // Top area for tooltip & animated bars
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(dataList.length, (index) {
                        final data = dataList[index];
                        final bool isPeak = index == peakIndex;

                        final barHeightFactor = data.amount <= 0
                            ? 0.08
                            : (data.amount / maxAmount).clamp(0.12, 1.0);
                        double barHeight = 90 * barHeightFactor;

                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Tooltip for peak month (FittedBox prevents overflow)
                              if (isPeak) ...[
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tooltipBgColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CustomText(
                                          text: "Earning",
                                          fontSize: 9,
                                          color: Colors.grey,
                                        ),
                                        CustomText(
                                          text:
                                              "€${data.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ] else
                                const SizedBox(height: 32),

                              // Animated Bar for smooth transitions
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                height: barHeight,
                                width: 14,
                                decoration: BoxDecoration(
                                  color: isPeak ? primaryYellow : darkBarColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Month Labels Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(dataList.length, (index) {
                      final data = dataList[index];
                      final bool isPeak = index == peakIndex;
                      return Expanded(
                        child: Center(
                          child: CustomText(
                            text: data.month,
                            fontSize: 10,
                            color: isPeak ? Colors.white : Colors.grey,
                            fontWeight: isPeak
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
