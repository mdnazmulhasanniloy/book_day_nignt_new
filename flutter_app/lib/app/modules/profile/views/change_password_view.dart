import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../core/resources/common_widget/custom_button.dart';
import '../../../core/resources/common_widget/custom_text_field.dart';
import '../controllers/profile_controller.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final controller = Get.find<ProfileController>();

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(title: "Change Password"),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CustomTextField(
              label: "Previous Password",
              hint: "••••••••",
              obscureText: true,
              controller: currentPasswordController,
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: "New Password",
              hint: "••••••••",
              obscureText: true,
              controller: newPasswordController,
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: "Confirm Password",
              hint: "••••••••",
              obscureText: true,
              controller: confirmPasswordController,
            ),
            const Spacer(),
            CustomButton(
              title: "Update Password",
              onTap: () async {
                bool success = await controller.changePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                  confirmPassword: confirmPasswordController.text,
                );

                if (success) {
                  Get.back();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
