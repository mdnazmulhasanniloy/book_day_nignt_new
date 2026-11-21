import 'package:bookdianight_app/app/core/extentions/theme_extention.dart';
import 'package:bookdianight_app/app/core/resources/app_assets/app_assets.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/activity/views/owner_activity_view.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/earning/views/owner_earning_view.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/owner_home/views/owner_home_view.dart';
import 'package:bookdianight_app/app/modules/profile/views/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/network/network_guard.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../stripe_connect/controllers/stripe_connect_controller.dart';
import '../../ticket_scanner/views/ticket_scanner_view.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OwnerDashboardController());

    final List<Widget> screens = [
      const OwnerHomeView(),
      const OwnerActivityView(),
      const OwnerEarningView(),
      const ProfileView(),
    ];

    final List<String> activeIcons = [
      AppAssets.navHomeActive,
      AppAssets.navBookingActive,
      AppAssets.navEarningActive,
      AppAssets.navProfileActive,
    ];
    final List<String> inactiveIcons = [
      AppAssets.navHomeInactive,
      AppAssets.navBookingInactive,
      AppAssets.navEarningInactive,
      AppAssets.navProfileInactive,
    ];

    final List<String> labels = ['Home', 'Activity', 'Earning', 'Profile'];

    return NetworkGuard(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Obx(() => screens[controller.selectedIndex.value]),

            // Custom Bottom Navigation Bar
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: Obx(() {
                Widget navItem(int index) => Expanded(
                  child: _NavItem(
                    icon: controller.selectedIndex.value == index
                        ? activeIcons[index]
                        : inactiveIcons[index],
                    label: labels[index],
                    isSelected: controller.selectedIndex.value == index,
                    // The earning active asset is a multi-colour tile; tinting
                    // flattens it into a solid square.
                    tintIcon: !(controller.selectedIndex.value == index &&
                        index == 2),
                    onTap: () => controller.selectedIndex.value = index,
                  ),
                );

                return SizedBox(
                  height: 70,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D0D),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            navItem(0),
                            navItem(1),
                            const SizedBox(width: _scanButtonSize + 8),
                            navItem(2),
                            navItem(3),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -_scanButtonSize / 2 + 8,
                        child: _ScanButton(
                          onTap: () => Get.to(() => const TicketScannerView()),
                        ),
                      ),
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

const double _scanButtonSize = 60;

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.tintIcon = true,
  });

  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool tintIcon;

  static const _gold = Color(0xFFE1B144);

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _gold : Colors.white.withValues(alpha: 0.55);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: isSelected ? 1.1 : 1,
            child: Image.asset(
              icon,
              color: tintIcon ? color : null,
              width: 22,
              height: 22,
            ),
          ),
          const SizedBox(height: 4),
          CustomText(
            text: label,
            color: color,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            maxLine: 1,
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _scanButtonSize,
        height: _scanButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: context.navbarGradient,
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE1B144).withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.qr_code_scanner_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class OwnerDashboardController extends GetxController {
  var selectedIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    StripeConnectController.ensure();
    if (Get.arguments != null && Get.arguments is int) {
      selectedIndex.value = Get.arguments;
    }
  }

  Future<bool> onBackPress() async {
    if (selectedIndex.value != 0) {
      selectedIndex.value = 0;
      return false;
    }
    return true;
  }
}
