import '../../../services/notification_router.dart';
import 'package:bookdianight_app/app/core/extentions/theme_extention.dart';
import 'package:bookdianight_app/app/core/resources/app_assets/app_assets.dart';
import 'package:bookdianight_app/app/modules/profile/views/profile_view.dart';
import '../favorite/views/favorite_clube_view.dart';
import 'package:bookdianight_app/app/modules/user_side/favorite/controllers/wishlist_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/auth/account_gate.dart';
import '../../../core/network/network_guard.dart';
import '../../../core/resources/common_widget/custom_text.dart';
import '../../../services/deep_link_service.dart';
import '../booking/views/my_booking_view.dart';
import '../explore/views/explore_view.dart';
import '../home/views/user_home_view.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UserDashboardController());
    Get.put(WishlistController(), permanent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.onUserDashboardReady();
      NotificationRouter.onDashboardReady();
    });

    final List<Widget> screens = [
      const HomeScreen(),
      const ExploreView(),
      const MyBookingsView(),
      const FavoriteClubeView(),
      const ProfileView(),
    ];

    final List<String> activeIcons = [
      AppAssets.navHomeActive,
      AppAssets.navExploreActive,
      AppAssets.navBookingActive,
      AppAssets.navFavoriteActive,
      AppAssets.navProfileActive,
    ];
    final List<String> inactiveIcons = [
      AppAssets.navHomeInactive,
      AppAssets.navExploreInactive,
      AppAssets.navBookingInactive,
      AppAssets.navFavoriteInactive,
      AppAssets.navProfileInactive,
    ];

    final List<String> labels = [
      'Home',
      'Explore',
      'Booking',
      'Favourite',
      'Profile',
    ];

    return NetworkGuard(
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: Obx(() => screens[controller.selectedIndex.value]),
            ),

            // Custom Bottom Navigation Bar
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: Obx(
                () => Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(activeIcons.length, (index) {
                      bool isSelected = controller.selectedIndex.value == index;
                      return GestureDetector(
                        onTap: () {
                          final needsAccount =
                              index == 2 || index == 3 || index == 4;
                          if (needsAccount && !AccountGate.isSignedIn) {
                            AccountGate.prompt();
                            return;
                          }
                          controller.selectedIndex.value = index;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 10 : 3,
                            vertical: isSelected ? 10 : 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? context.navbarGradient
                                : null,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: isSelected
                              ? Row(
                                  children: [
                                    Image.asset(
                                      activeIcons[index],
                                      color: Colors.white,
                                      width: 22,
                                    ),
                                    const SizedBox(width: 5),
                                    CustomText(
                                      text: labels[index],
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      inactiveIcons[index],
                                      color: Colors.white.withValues(alpha: .6),
                                      width: 20,
                                    ),
                                    const SizedBox(height: 3),
                                    CustomText(
                                      text: labels[index],
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 10,
                                      maxLine: 1,
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserDashboardController extends GetxController {
  var selectedIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
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
