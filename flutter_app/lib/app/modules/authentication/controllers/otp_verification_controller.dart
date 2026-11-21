import 'dart:async';
import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/network/api_expection.dart';
import 'package:bookdianight_app/app/core/network/end_point.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:bookdianight_app/app/core/resources/app_loader/custom_animated_loader.dart';
import 'package:bookdianight_app/app/core/utils/custom_snack_bar.dart';
import 'package:bookdianight_app/app/core/utils/device_helper.dart';
import 'package:bookdianight_app/app/services/notification_services.dart';
import 'package:bookdianight_app/app/modules/authentication/auth_repository/auth_repository.dart';
import 'package:bookdianight_app/app/modules/authentication/views/login_view.dart';
import 'package:bookdianight_app/app/modules/authentication/views/new_password_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

class OtpVerificationController extends GetxController {
  final AuthRepository _authRepo = AuthRepository();

  // 6-Digit OTP Controllers
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  late Timer _timer;
  var remainingSeconds = 60.obs;
  var canResend = false.obs;
  var isLoading = false.obs;

  String? email;

  @override
  void onInit() {
    super.onInit();
    email = Get.arguments as String?;
    startTimer();
  }

  void startTimer() {
    remainingSeconds.value = 60;
    canResend.value = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        _timer.cancel();
        canResend.value = true;
      }
    });
  }

  Future<void> resendCode(bool isFromSignUp) async {
    if (!canResend.value) return;

    try {
      Response response;
      if (isFromSignUp) {
        String deviceId = DeviceHelper.getDeviceIdentifier();
        String? token = LocalStorage.getData(key: AppConst.verificationToken);
        response = await _authRepo.resendOtp(
          body: {"email": email, "deviceIdentifier": deviceId},
          token: token,
        );
      } else {
        String? resetToken = LocalStorage.getData(
          key: AppConst.resetPasswordToken,
        );
        response = await _authRepo.resendRecoverOtp(token: resetToken);
      }

      dynamic resData = response.data;
      if (resData != null && resData['success'] == true) {
        startTimer();
        CustomSnackBar.success(
          message: resData['message'] ?? "New OTP has been sent.",
        );
      } else {
        startTimer();
        CustomSnackBar.success(message: "New OTP has been sent.");
      }
    } catch (e) {
      startTimer();
      CustomSnackBar.success(message: "New OTP has been sent.");
    }
  }

  Future<void> verifyOtp(bool isFromSignUp) async {
    String otp = otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      CustomSnackBar.error(message: "Please enter 6-digit OTP code.");
      return;
    }

    try {
      isLoading.value = true;
      Get.dialog(
        const Center(child: CustomAnimationLoader()),
        barrierDismissible: false,
      );

      Response response;
      if (isFromSignUp) {
        // Signup OTP verification
        String deviceId = DeviceHelper.getDeviceIdentifier();
        final fcmToken = await NotificationService().currentToken();
        String? token = LocalStorage.getData(key: AppConst.verificationToken);

        Map<String, dynamic> body = {
          "otp": otp,
          "deviceIdentifier": deviceId,
          "fcmToken": fcmToken,
          "platform": DeviceHelper.getPlatform(),
        };

        response = await _authRepo.verifyOtp(
          endpoint: EndPoint.VERIFY_EMAIL,
          body: body,
          token: token,
        );
      } else {
        // Recover / Forgot password OTP verification (Body: {"otp": "123456"} ONLY)
        String? resetToken = LocalStorage.getData(
          key: AppConst.resetPasswordToken,
        );

        Map<String, dynamic> body = {"otp": otp};

        response = await _authRepo.verifyOtp(
          endpoint: EndPoint.FORGOT_PASSWORD_VERIFY,
          body: body,
          token: resetToken,
        );
      }

      Get.back(); // close loader
      isLoading.value = false;

      dynamic resData = response.data;
      if (resData != null && resData['success'] == true) {
        CustomSnackBar.success(
          message: resData['message'] ?? "OTP Verified Successfully!",
        );

        if (isFromSignUp) {
          Get.offAll(() => const LoginView());
        } else {
          Get.to(() => const NewPasswordView(), arguments: email);
        }
      } else {
        String msg =
            resData?['message'] ?? "Invalid OTP code. Please try again.";
        CustomSnackBar.error(message: msg);
      }
    } catch (e) {
      Get.back();
      isLoading.value = false;
      debugPrint("Verify OTP Error: $e");
      CustomSnackBar.error(
        message: clientErrorMessage(
          e,
          'OTP verification failed. Please try again.',
        ),
      );
    }
  }

  void onOtpDigitChanged(String value, int index) {
    if (value.length == 1 && index < otpControllers.length - 1) {
      otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      otpFocusNodes[index - 1].requestFocus();
    } else if (value.length == 1 && index == otpControllers.length - 1) {
      otpFocusNodes[index].unfocus();
    }
  }

  @override
  void onClose() {
    _timer.cancel();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    super.onClose();
  }
}
