import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../../dashboard/user_dashboard.dart';

class EntryQrCodeView extends StatelessWidget {
  const EntryQrCodeView({
    super.key,
    required this.orderId,
    this.title = 'Entry QR Code',
    this.showHomeButton = true,
  });

  final String orderId;
  final String title;
  final bool showHomeButton;

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D0D0D);
    const cardBgColor = Color(0xFF161616);
    const primaryYellow = Color(0xFFDCA73A);
    final payload = orderId.trim();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CustomAppBar(title: title, backgroundColor: bgColor),
      bottomNavigationBar: showHomeButton
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: CustomButton(
                  title: 'Back To Homepage',
                  buttonColor: primaryYellow,
                  isGradient: false,
                  borderRadius: 16,
                  paddingVertical: 14,
                  onTap: () => Get.offAll(() => const UserDashboard()),
                ),
              ),
            )
          : null,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomText(
                  text: 'Entry Pass',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryYellow,
                ),
                const SizedBox(height: 4),
                const CustomText(
                  text: 'Scan once at the door',
                  fontSize: 12,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                Center(
                  child: payload.isEmpty
                      ? const CustomText(
                          text: 'Door QR is not ready yet',
                          color: Colors.white70,
                        )
                      : Container(
                          height: 220,
                          width: 220,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: BarcodeWidget(
                            barcode: Barcode.qrCode(),
                            data: payload,
                            color: Colors.black,
                            drawText: false,
                          ),
                        ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        color: primaryYellow,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: CustomText(
                          text: 'Keep screen brightness high',
                          fontSize: 13,
                          color: Colors.white,
                          textAlign: TextAlign.center,
                          maxLine: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
}
