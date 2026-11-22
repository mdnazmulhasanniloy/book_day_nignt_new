import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/network/base_client.dart';
import 'package:bookdianight_app/app/core/network/end_point.dart';
import 'package:bookdianight_app/app/core/network/auth_refresh_coordinator.dart';
import 'package:bookdianight_app/app/core/network/auth_session.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:bookdianight_app/app/core/resources/app_loader/custom_animated_loader.dart';
import 'package:bookdianight_app/app/core/utils/custom_snack_bar.dart';
import 'package:bookdianight_app/app/core/location/auth_coordinates.dart';
import 'package:bookdianight_app/app/core/utils/device_helper.dart';
import 'package:bookdianight_app/app/services/notification_services.dart';
import 'package:bookdianight_app/app/modules/authentication/auth_repository/auth_repository.dart';
import 'package:bookdianight_app/app/modules/authentication/views/forgot_password_view.dart';
import 'package:bookdianight_app/app/modules/authentication/views/sign_up_view.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/dashboard/dashboard/owner_dashboard.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/stripe_connect/views/payout_setup_view.dart';
import 'package:bookdianight_app/app/modules/user_side/dashboard/user_dashboard.dart';
import 'package:dio/dio.dart';
import 'package:bookdianight_app/app/core/network/api_expection.dart';
import 'package:bookdianight_app/app/modules/authentication/views/otp_verification_view.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get/get.dart' hide Response;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginController extends GetxController {
  final AuthRepository _authRepo = AuthRepository();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  var isRememberMe = false.obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSavedCredentials();
  }

  /// Loads saved Remember Me email & password from LocalStorage
  void loadSavedCredentials() {
    bool savedRemember =
        LocalStorage.getData(key: AppConst.isRememberMe) ?? false;
    isRememberMe.value = savedRemember;

    if (savedRemember) {
      String? savedEmail = LocalStorage.getData(key: AppConst.savedEmail);
      String? savedPassword =
          LocalStorage.getData(key: AppConst.savedPassword);

      if (savedEmail != null && savedEmail.isNotEmpty) {
        emailController.text = savedEmail;
      }
      if (savedPassword != null && savedPassword.isNotEmpty) {
        passwordController.text = savedPassword;
      }
    }
  }

  void toggleRememberMe(bool value) {
    isRememberMe.value = value;
  }

  Future<void> login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty) {
      CustomSnackBar.error(message: "Please enter your email address");
      return;
    }

    if (!GetUtils.isEmail(email)) {
      CustomSnackBar.error(message: "Please enter a valid email address");
      return;
    }

    if (password.isEmpty) {
      CustomSnackBar.error(message: "Please enter your password");
      return;
    }

    // Save or clear Remember Me credentials
    if (isRememberMe.value) {
      await LocalStorage.saveData(key: AppConst.isRememberMe, data: true);
      await LocalStorage.saveData(key: AppConst.savedEmail, data: email);
      await LocalStorage.saveData(key: AppConst.savedPassword, data: password);
    } else {
      await LocalStorage.saveData(key: AppConst.isRememberMe, data: false);
      await LocalStorage.removeData(key: AppConst.savedEmail);
      await LocalStorage.removeData(key: AppConst.savedPassword);
    }

    String deviceId = DeviceHelper.getDeviceIdentifier();
    final fcmToken = await NotificationService().currentToken();
    final coords = await AuthCoordinates.read();

    Map<String, dynamic> body = {
      "email": email,
      "password": password,
      "deviceIdentifier": deviceId,
      "platform": (!kIsWeb && Platform.isIOS) ? "IOS" : "ANDROID",
      "fcmToken": fcmToken,
      "rememberMe": isRememberMe.value,
      "lng": coords.lng,
      "lat": coords.lat,
    };

    try {
      isLoading.value = true;
      Get.dialog(
        const Center(child: CustomAnimationLoader()),
        barrierDismissible: false,
      );

      Response response = await _authRepo.login(body);

      dynamic resData = response.data;
      if (resData != null && resData['success'] == true) {
        final data = resData['data'] is Map
            ? Map<String, dynamic>.from(resData['data'] as Map)
            : null;
        String? token = AuthRepository.sessionToken(data);
        String? role = data?['role']?.toString();

        if (token == null || token.isEmpty) {
          _closeLoader();
          CustomSnackBar.error(message: "Login failed. Please try again.");
          return;
        }

        if (data?['isUserVerified'] == false) {
          await LocalStorage.saveData(
            key: AppConst.verificationToken,
            data: token,
          );
          _closeLoader();
          Get.to(
            () => const OtpVerificationView(comeFromSignUp: true),
            arguments: email,
          );
          return;
        }

        await persistLoginSession(const LocalAuthTokenStore(), data);
        if (role != null) {
          await LocalStorage.saveData(key: AppConst.role, data: role);
        }
        await LocalStorage.saveData(key: 'deviceIdentifier', data: deviceId);

        final payoutReady = role == 'CLUB_OWNER'
            ? await _isPayoutConnected()
            : false;

        _closeLoader();
        FocusManager.instance.primaryFocus?.unfocus();
        CustomSnackBar.success(
            message: resData['message'] ?? "Login successful!");

        if (role == 'CLUB_OWNER') {
          if (payoutReady) {
            Get.offAll(() => const OwnerDashboard());
          } else {
            Get.offAll(() => const PayoutSetupView());
          }
        } else {
          Get.offAll(() => const UserDashboard());
        }
      } else {
        _closeLoader();
        String msg = resData?['message'] ?? "Login failed. Please try again.";
        CustomSnackBar.error(message: msg);
      }
    } catch (e) {
      _closeLoader();
      debugPrint("Login Error: $e");
      CustomSnackBar.error(
        message: clientErrorMessage(e, 'Login failed. Please try again.'),
      );
    }
  }

  void _closeLoader() {
    if (Get.isDialogOpen == true) Get.back();
    isLoading.value = false;
  }

  Future<bool> _isPayoutConnected() async {
    try {
      final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
      if (token == null || token.isEmpty) return false;
      final response = await BaseClient().get(
        endpoint: EndPoint.connectStatus,
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is Map && data['canCreateListings'] == true) return true;
      return false;
    } catch (error) {
      debugPrint('Payout status check failed: $error');
      return false;
    }
  }

  static const _googleIosClientId =
      '878417792682-06qmc1n72p6l6rgm98atua2kbbtpdg00.apps.googleusercontent.com';
  static const _googleServerClientId =
      '878417792682-kmnp9b7jl61abcrv8ehfep80eb6a5njv.apps.googleusercontent.com';

  Future<void> continueWithGoogle() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'openid'],
        clientId: (!kIsWeb && Platform.isIOS) ? _googleIosClientId : null,
        serverClientId: _googleServerClientId,
      );
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) return;

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken?.trim() ?? '';
      if (idToken.isEmpty) {
        CustomSnackBar.error(
          message:
              'Google did not return an ID token. Try again, or check the iOS client ID.',
        );
        return;
      }

      await _completeSocialLogin(
        provider: 'GOOGLE',
        providerLabel: 'Google',
        idToken: idToken,
        nonce: _jwtClaim(idToken, 'nonce'),
      );
    } on PlatformException catch (error) {
      _closeLoader();
      CustomSnackBar.error(
        message: error.message ?? 'Google sign-in was not completed.',
      );
    } catch (error) {
      _closeLoader();
      debugPrint('Google login error: $error');
      CustomSnackBar.error(message: 'Google login failed. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> continueWithApple() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final rawNonce = _randomNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final idToken = credential.identityToken?.trim() ?? '';
      if (idToken.isEmpty) {
        CustomSnackBar.error(
          message: 'Apple did not return an identity token. Please try again.',
        );
        return;
      }

      await _completeSocialLogin(
        provider: 'APPLE',
        providerLabel: 'Apple',
        idToken: idToken,
        nonce: _jwtClaim(idToken, 'nonce') == null ? null : rawNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      _closeLoader();
      if (error.code == AuthorizationErrorCode.canceled) return;
      CustomSnackBar.error(
        message: error.message.isEmpty
            ? 'Apple sign-in was not completed.'
            : error.message,
      );
    } on SignInWithAppleNotSupportedException {
      _closeLoader();
      CustomSnackBar.error(
        message: 'Sign in with Apple is not supported on this device.',
      );
    } catch (error) {
      _closeLoader();
      debugPrint('Apple login error: $error');
      CustomSnackBar.error(message: 'Apple login failed. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String? _jwtClaim(String token, String key) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      final value = payload[key]?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _completeSocialLogin({
    required String provider,
    required String providerLabel,
    required String idToken,
    String? nonce,
  }) async {
    Get.dialog(
      const Center(child: CustomAnimationLoader()),
      barrierDismissible: false,
    );

    try {
      final deviceId = DeviceHelper.getDeviceIdentifier();
      final fcmToken = await NotificationService().currentToken();
      final coords = await AuthCoordinates.read();
      final request = <String, dynamic>{
        'idToken': idToken,
        'provider': provider,
        'deviceIdentifier': deviceId,
        'platform': (!kIsWeb && Platform.isIOS) ? 'IOS' : 'ANDROID',
        'lat': coords.lat,
        'lng': coords.lng,
      };
      final fcm = fcmToken.trim();
      if (fcm.isNotEmpty) request['fcmToken'] = fcm;
      final nonceValue = nonce?.trim() ?? '';
      if (nonceValue.isNotEmpty) request['nonce'] = nonceValue;

      final response = await _authRepo.socialLogin(request);
      final resData = response.data;
      final body = resData is Map
          ? Map<String, dynamic>.from(resData)
          : null;
      final rawData = body?['data'];
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : null;
      final token = data?['token']?.toString().trim() ?? '';
      if (body?['success'] != true || token.isEmpty) {
        _closeLoader();
        final message = body?['message']?.toString() ?? '';
        CustomSnackBar.error(
          message: message.isEmpty
              ? '$providerLabel login failed. Please try again.'
              : message,
        );
        return;
      }

      final role = data?['role']?.toString();
      await persistLoginSession(const LocalAuthTokenStore(), data);
      if (role != null && role.isNotEmpty) {
        await LocalStorage.saveData(key: AppConst.role, data: role);
      }
      await LocalStorage.saveData(key: 'deviceIdentifier', data: deviceId);

      final payoutReady =
          role == 'CLUB_OWNER' ? await _isPayoutConnected() : false;

      _closeLoader();
      final message = body?['message']?.toString() ?? '';
      CustomSnackBar.success(
        message: message.isEmpty ? 'Social login successful' : message,
      );
      if (role == 'CLUB_OWNER') {
        Get.offAll(
          () => payoutReady ? const OwnerDashboard() : const PayoutSetupView(),
        );
      } else {
        Get.offAll(() => const UserDashboard());
      }
    } on ApiException catch (error) {
      _closeLoader();
      CustomSnackBar.error(
        message: clientErrorMessage(
          error,
          '$providerLabel login failed. Please try again.',
        ),
      );
    } catch (error) {
      _closeLoader();
      debugPrint('$providerLabel login error: $error');
      CustomSnackBar.error(
        message: '$providerLabel login failed. Please try again.',
      );
    }
  }

  void goToSignUp() {
    Get.to(() => const SignUpView());
  }

  void goToForgotPassword() {
    Get.to(() => const ForgotPasswordView());
  }
}
