import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../stripe_connect/controllers/stripe_connect_controller.dart';
import '../../stripe_connect/views/payout_setup_view.dart';
import '../controllers/owner_activity_controller.dart';
import '../model/promo_api_model.dart';
import '../views/add_club_view.dart';
import '../views/add_event_view.dart';
import '../views/add_promo_view.dart';

class ChooseCreateTypeSheet extends StatelessWidget {
  const ChooseCreateTypeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OwnerActivityController>();
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            const CustomText(
              text: "Choose One",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 24),

            // Option 1: Club
            Obx(
              () => _buildTypeOption(
                title: "Club",
                icon: Icons.chair_outlined,
                isSelected: controller.selectedCreateType.value == "Club",
                onTap: () => controller.selectedCreateType.value = "Club",
                primaryYellow: primaryYellow,
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Event
            Obx(
              () => _buildTypeOption(
                title: "Event",
                icon: Icons.calendar_today_outlined,
                isSelected: controller.selectedCreateType.value == "Event",
                onTap: () => controller.selectedCreateType.value = "Event",
                primaryYellow: primaryYellow,
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => _buildTypeOption(
                title: "Promo code",
                icon: Icons.local_offer_outlined,
                isSelected: controller.selectedCreateType.value == "Promo",
                onTap: () => controller.selectedCreateType.value = "Promo",
                primaryYellow: primaryYellow,
              ),
            ),
            const SizedBox(height: 32),

            // Next Button
            CustomButton(
              title: "Next",
              buttonColor: primaryYellow,
              isGradient: false,
              borderRadius: 16,
              onTap: () async {
                final type = controller.selectedCreateType.value;
                Get.back();
                if (type == "Promo") {
                  final created = await Get.to(() => const AddPromoView());
                  if (created is PromoDataModel) {
                    controller.rememberCreatedPromo(created);
                  }
                  return;
                }
                final connect = StripeConnectController.ensure();
                final allowed = await connect.ensureCanCreateListings();
                if (!allowed) {
                  await _showPayoutRequiredSheet(connect.status.value?.title);
                  return;
                }
                if (type == "Club") {
                  Get.to(() => const AddClubView());
                } else {
                  Get.to(() => const AddEventView());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPayoutRequiredSheet(String? title) {
    return Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF161616),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.account_balance_outlined,
                color: Color(0xFFDCA73A),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                title ?? 'Set up your payout account',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect your payout account before creating a club or event.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDCA73A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Get.back();
                    Get.to(() => const PayoutSetupView(fromMenu: true));
                  },
                  child: const Text(
                    'Set up payouts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildTypeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryYellow,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryYellow : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryYellow : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomText(
                text: title,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Container(
              height: 20,
              width: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryYellow : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryYellow : Colors.grey,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
