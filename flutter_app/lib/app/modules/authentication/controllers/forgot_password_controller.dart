import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/network/api_expection.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:bookdianight_app/app/core/resources/app_loader/custom_animated_loader.dart';
import 'package:bookdianight_app/app/core/utils/custom_snack_bar.dart';
import 'package:bookdianight_app/app/modules/authentication/auth_repository/auth_repository.dart';
import 'package:bookdianight_app/app/modules/authentication/views/login_view.dart';
import 'package:bookdianight_app/app/modules/authentication/views/otp_verification_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

class ForgotPasswordController extends GetxController {
  final AuthRepository _authRepo = AuthRepository();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  var isLoading = false.obs;

  // Forgot Password Screen Logic - Find user by email and send OTP
  Future<void> sendCode() async {
    String email = emailController.text.trim();
    if (email.isEmpty || !GetUtils.isEmail(email)) {
      CustomSnackBar.error(message: "Please enter a valid email address.");
      return;
    }

    try {
      isLoading.value = true;
      Get.dialog(
        const Center(child: CustomAnimationLoader()),
        barrierDismissible: false,
      );

      Response response = await _authRepo.forgotPassword(email);

      Get.back(); // close loader
      isLoading.value = false;

      dynamic resData = response.data;
      if (resData != null && resData['success'] == true) {
        String? resetToken = resData['data']?['token'];
        if (resetToken != null && resetToken.isNotEmpty) {
          await LocalStorage.saveData(
              key: AppConst.resetPasswordToken, data: resetToken);
        }

        CustomSnackBar.success(
            message: resData['message'] ?? "OTP code sent to your email.");

        Get.to(() => const OtpVerificationView(comeFromSignUp: false),
            arguments: email);
      } else {
        String msg = resData?['message'] ?? "Failed to send OTP code.";
        CustomSnackBar.error(message: msg);
      }
    } catch (e) {
      Get.back();
      isLoading.value = false;
      debugPrint("ForgotPassword sendCode error: $e");
      CustomSnackBar.error(
        message: clientErrorMessage(
          e,
          'Error sending recovery code. Try again.',
        ),
      );
    }
  }

  // New Password Screen Logic - Reset Password
  Future<void> confirmNewPassword() async {
    String newPassword = newPasswordController.text;
    String confirmPassword = confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      CustomSnackBar.error(message: "Please fill in both password fields.");
      return;
    }
    if (newPassword != confirmPassword) {
      CustomSnackBar.error(message: "Passwords do not match.");
      return;
    }
    if (newPassword.length < 6) {
      CustomSnackBar.error(
          message: "Password must be at least 6 characters long.");
      return;
    }

    String? resetToken = LocalStorage.getData(key: AppConst.resetPasswordToken);

    try {
      isLoading.value = true;
      Get.dialog(
        const Center(child: CustomAnimationLoader()),
        barrierDismissible: false,
      );

      Response response = await _authRepo.resetPassword(
        body: {"password": newPassword},
        token: resetToken,
      );

      Get.back(); // close loader
      isLoading.value = false;

      dynamic resData = response.data;
      if (resData != null && resData['success'] == true) {
        await LocalStorage.removeData(key: AppConst.resetPasswordToken);
        CustomSnackBar.success(
            message: resData['message'] ?? "Password reset successful!");
        Get.offAll(() => const LoginView());
      } else {
        String msg = resData?['message'] ?? "Password reset failed.";
        CustomSnackBar.error(message: msg);
      }
    } catch (e) {
      Get.back();
      isLoading.value = false;
      debugPrint("Reset Password Error: $e");
      CustomSnackBar.error(
        message: clientErrorMessage(
          e,
          'Failed to reset password. Please try again.',
        ),
      );
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
