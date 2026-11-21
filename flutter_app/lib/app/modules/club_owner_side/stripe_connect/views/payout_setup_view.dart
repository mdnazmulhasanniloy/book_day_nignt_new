import 'package:bookdianight_app/app/core/resources/common_widget/custom_button.dart';
import 'package:bookdianight_app/app/core/resources/common_widget/custom_text.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/dashboard/dashboard/owner_dashboard.dart';
import 'package:bookdianight_app/app/modules/profile/controllers/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/stripe_connect_controller.dart';

class PayoutSetupView extends StatefulWidget {
  const PayoutSetupView({super.key, this.fromMenu = false});

  /// Opened from the dashboard, home banner, or profile.
  final bool fromMenu;

  @override
  State<PayoutSetupView> createState() => _PayoutSetupViewState();
}

class _PayoutSetupViewState extends State<PayoutSetupView> {
  StripeConnectController? _controller;

  @override
  void initState() {
    super.initState();
    final alreadyRegistered = Get.isRegistered<StripeConnectController>();
    _controller = StripeConnectController.ensure();
    // The controller is permanent, so refresh to avoid showing a previous
    // account's status after re-login.
    if (alreadyRegistered) _controller!.refreshStatus();
  }

  void _logout() {
    final profile = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    profile.logout();
  }

  Future<void> _primaryAction() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.status.value?.isReady == true) {
      if (widget.fromMenu) {
        Get.back();
      } else {
        Get.offAll(() => const OwnerDashboard());
      }
      return;
    }
    await controller.openOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFDCA73A);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _controller == null
              ? const SizedBox.shrink()
              : Obx(() {
                  final status = _controller!.status.value;
                  final loading =
                      _controller!.isLoading.value && status == null;
                  return _body(
                    gold: gold,
                    title: status?.title ?? 'Set up your payout account',
                    message:
                        status?.message ??
                        'Connect your bank account with Stripe so BookdiaNight can pay out your earnings.',
                    actionLabel: status?.isReady == true
                        ? (widget.fromMenu ? 'Done' : 'Go to dashboard')
                        : (status?.actionLabel ?? 'Set up payout account'),
                    isReady: status?.isReady == true,
                    isLoading: loading || _controller!.isOpening.value,
                  );
                }),
        ),
      ),
    );
  }

  Widget _body({
    required Color gold,
    required String title,
    required String message,
    required String actionLabel,
    required bool isReady,
    required bool isLoading,
  }) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: widget.fromMenu
              ? IconButton(
                  onPressed: Get.back,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                )
              : const SizedBox(height: 48),
        ),
        const Spacer(),
        Container(
          height: 88,
          width: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gold.withValues(alpha: 0.12),
          ),
          child: Icon(
            isReady
                ? Icons.verified_outlined
                : Icons.account_balance_outlined,
            color: gold,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        CustomText(
          text: title,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          textAlign: TextAlign.center,
          maxLine: 3,
        ),
        const SizedBox(height: 12),
        CustomText(
          text: message,
          fontSize: 14,
          color: const Color(0xFFA0A0A0),
          textAlign: TextAlign.center,
          maxLine: 6,
        ),
        const Spacer(),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: CircularProgressIndicator(color: Color(0xFFDCA73A)),
          ),
        CustomButton(
          title: actionLabel,
          buttonColor: const Color(0xFFDCA73A),
          isGradient: false,
          borderRadius: 16,
          paddingVertical: 14,
          titleColor: Colors.black,
          onTap: isLoading ? null : _primaryAction,
        ),
        if (!widget.fromMenu && !isReady) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading ? null : _logout,
            child: const Text(
              'Log out',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ],
      ],
    );
  }
}
