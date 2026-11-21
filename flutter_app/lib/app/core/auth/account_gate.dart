import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../local_storage/local_storage.dart';
import '../resources/app_const/app_const.dart';
import '../resources/common_widget/custom_button.dart';
import '../resources/common_widget/custom_text.dart';
import '../../modules/authentication/views/login_view.dart';
import '../../modules/authentication/views/sign_up_view.dart';

class AccountGate {
  static bool _showing = false;

  static bool get isSignedIn {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return token != null && token.isNotEmpty;
  }

  static Future<bool> ensure() async {
    if (isSignedIn) return true;
    await prompt();
    return isSignedIn;
  }

  static Future<void> prompt() async {
    if (isSignedIn || _showing) return;
    _showing = true;
    try {
      await Get.dialog<void>(
        Dialog(
          backgroundColor: const Color(0xFF121212),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: Get.back,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
                ),
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1B144).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFFE1B144),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                const CustomText(
                  text: 'Account required',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const CustomText(
                  text:
                      'Create an account to book, save favorites, and open your profile.',
                  fontSize: 14,
                  color: Color(0xFFB8B8B8),
                  textAlign: TextAlign.center,
                  height: 1.4,
                ),
                const SizedBox(height: 22),
                const _AccountPerk(icon: Icons.event_seat_outlined, label: 'Reserve tables and tickets'),
                const SizedBox(height: 10),
                const _AccountPerk(icon: Icons.favorite_border_rounded, label: 'Save clubs and events'),
                const SizedBox(height: 10),
                const _AccountPerk(icon: Icons.calendar_today_outlined, label: 'View bookings and profile'),
                const SizedBox(height: 24),
                CustomButton(
                  title: 'Create account',
                  buttonColor: const Color(0xFFE1B144),
                  titleColor: Colors.black,
                  isGradient: false,
                  borderRadius: 14,
                  paddingVertical: 14,
                  onTap: () {
                    Get.back();
                    Get.to(() => const SignUpView());
                  },
                ),
                const SizedBox(height: 10),
                CustomButton(
                  title: 'Sign in',
                  buttonColor: Colors.transparent,
                  titleColor: Colors.white,
                  isGradient: false,
                  borderRadius: 14,
                  paddingVertical: 14,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  onTap: () {
                    Get.back();
                    Get.to(() => const LoginView());
                  },
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: true,
      );
    } finally {
      _showing = false;
    }
  }
}

class _AccountPerk extends StatelessWidget {
  const _AccountPerk({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE1B144)),
        const SizedBox(width: 12),
        Expanded(
          child: CustomText(
            text: label,
            fontSize: 13,
            color: const Color(0xFFE6E6E6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
