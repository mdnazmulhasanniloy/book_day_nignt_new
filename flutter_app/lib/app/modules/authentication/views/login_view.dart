import 'dart:io';

import 'package:bookdianight_app/app/core/resources/app_colors/App_Colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/resources/app_assets/app_assets.dart';
import '../../../core/resources/common_widget/custom_button.dart';
import '../../../core/resources/common_widget/custom_checkbox.dart';
import '../../../core/resources/common_widget/custom_text.dart';
import '../../../core/resources/common_widget/custom_text_field.dart';
import '../../../core/network/network_guard.dart';
import '../../../core/resources/common_widget/gradient_scaffold.dart';
import '../controllers/sign_in_controller.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final LoginController controller = Get.put(LoginController());
    return NetworkGuard(
      child: GradientScaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),

                // --- Logo ---
                Image.asset(AppAssets.appLogo, height: 64, fit: BoxFit.contain),
                const SizedBox(height: 12),

                // --- Title & Subtitle ---
                const CustomText(
                  text: "Sign in to your Account",
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                CustomText(
                  text: "Enter your email and password to log in",
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // --- Email Field ---
                CustomTextField(
                  controller: controller.emailController,
                  label: "Email",
                  hint: "Enter your email",
                  labelColor: Colors.white,
                  hintColor: Colors.white.withValues(alpha: 0.4),
                  filled: true,
                  isBorder: false,
                  borderRadius: 12.0,
                ),
                const SizedBox(height: 12),

                // --- Password Field ---
                CustomTextField(
                  controller: controller.passwordController,
                  label: "Password",
                  hint: "••••••••",
                  labelColor: Colors.white,
                  hintColor: Colors.white.withValues(alpha: 0.4),
                  filled: true,
                  isBorder: false,
                  obscureText: true,
                  borderRadius: 12.0,
                ),
                const SizedBox(height: 16),

                // --- Remember Me & Forgot Password ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(
                      () => CustomCheckBox(
                        title: "Remember me",
                        isChecked: controller.isRememberMe.value,
                        activeColor: AppColors.mainColor,
                        inactiveColor: Colors.white,
                        textColor: Colors.white,
                        borderWidth: 1.5,
                        fontSize: 13,
                        onChanged: (value) {
                          controller.toggleRememberMe(value);
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.goToForgotPassword,
                      child: const CustomText(
                        text: "Forgot Password ?",
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mainColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // --- Login Button ---
                CustomButton(
                  title: "Login",
                  titleColor: Colors.white,
                  fontSize: 16,
                  borderRadius: 12.0,
                  onTap: controller.login,
                ),
                const SizedBox(height: 16),

                // --- Sign in with Divider ---
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.2),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: CustomText(
                        text: "Sign in with",
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.2),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Google Login Button ---
                CustomButton(
                  title: "",
                  buttonColor: const Color(0xFF151515),
                  isGradient: false,
                  borderRadius: 12.0,
                  onTap: controller.continueWithGoogle,
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        AppAssets.googleIcon,
                        height: 22,
                        width: 22,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const CustomText(
                        text: "Continue with Google",
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                if (Platform.isIOS) ...[
                  const SizedBox(height: 10),

                  // --- Apple Login Button ---
                  CustomButton(
                    title: "",
                    buttonColor: const Color(0xFF151515),
                    isGradient: false,
                    borderRadius: 12.0,
                    onTap: controller.continueWithApple,
                    widget: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apple, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        CustomText(
                          text: "Continue with Apple",
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // --- Sign Up Text ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomText(
                      text: "Don't have an account? ",
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    GestureDetector(
                      onTap: controller.goToSignUp,
                      child: const CustomText(
                        text: "Sign Up",
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mainColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
