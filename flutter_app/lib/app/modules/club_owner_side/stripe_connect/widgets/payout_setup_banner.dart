import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/resources/common_widget/custom_text.dart';
import '../controllers/stripe_connect_controller.dart';
import '../views/payout_setup_view.dart';

class PayoutSetupBanner extends StatelessWidget {
  const PayoutSetupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StripeConnectController.ensure();
    return Obx(() {
      final status = controller.status.value;
      if (status == null || status.canCreateListings) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Material(
          color: const Color(0xFF1A1408),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Get.to(() => const PayoutSetupView(fromMenu: true)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFDCA73A).withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    color: Color(0xFFDCA73A),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          text: status.title,
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          maxLine: 2,
                        ),
                        const SizedBox(height: 4),
                        const CustomText(
                          text: 'Required before you create a club or event',
                          color: Color(0xFFA0A0A0),
                          fontSize: 12,
                          maxLine: 2,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
