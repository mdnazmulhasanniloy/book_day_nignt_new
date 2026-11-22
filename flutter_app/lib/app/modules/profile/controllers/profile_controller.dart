import '../../../services/notification_router.dart';
import 'dart:io';

import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/network/base_client.dart';
import 'package:bookdianight_app/app/core/network/auth_session.dart';
import 'package:bookdianight_app/app/core/network/end_point.dart';
import 'package:bookdianight_app/app/core/network/logout_flow.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:bookdianight_app/app/core/resources/app_loader/custom_animated_loader.dart';
import 'package:bookdianight_app/app/core/utils/custom_snack_bar.dart';
import 'package:bookdianight_app/app/core/utils/device_helper.dart';
import 'package:bookdianight_app/app/core/utils/personal_details.dart';
import 'package:bookdianight_app/app/modules/authentication/auth_repository/auth_repository.dart';
import 'package:bookdianight_app/app/modules/authentication/views/login_view.dart';
import 'package:bookdianight_app/app/modules/profile/model/profile_model.dart';
import 'package:bookdianight_app/app/services/deep_link_service.dart';
import 'package:bookdianight_app/app/services/media_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

class ProfileController extends GetxController {
  final AuthRepository _authRepo = AuthRepository();

  // User Profile Observables (Empty by default)
  var userName = "".obs;
  var userEmail = "".obs;
  var userPhone = "".obs;
  var userLocation = "".obs;
  var userAvatar = "".obs;
  var userRole = "".obs;
  var userGender = Rxn<Gender>();
  var userDateOfBirth = Rxn<DateTime>();

  var userModel = Rxn<UserModel>();

  var selectedLanguage = "English".obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserProfile();
  }

  /// Fetches User Profile from API using AuthRepository
  Future<void> fetchUserProfile() async {
    String? token = LocalStorage.getData(key: AppConst.accessToken);
    if (token == null || token.isEmpty) return;

    try {
      isLoading.value = true;
      ProfileResponseModel? res = await _authRepo.getProfile(token);
      isLoading.value = false;

      if (res != null && res.success && res.user != null) {
        UserModel user = res.user!;
        userModel.value = user;

        userName.value = user.name ?? "";
        userEmail.value = user.email ?? "";
        userPhone.value = user.phoneNumber ?? "";
        userRole.value = user.accountRole ?? "";

        if (user.profile != null) {
          userLocation.value = user.profile!.location ?? "";
          userAvatar.value = user.profile!.profileAvatar ?? "";
          userGender.value = Gender.fromApi(user.profile!.gender);
          userDateOfBirth.value =
              DateOfBirth.fromApi(user.profile!.dateOfBirth);
        }
      }
    } catch (e) {
      isLoading.value = false;
      debugPrint("Profile fetch error: $e");
    }
  }

  /// Updates User Profile via `PATCH /api/v1/profile`
  Future<bool> updateProfile({
    required String name,
    required String phone,
    required String location,
    Gender? gender,
    DateTime? dateOfBirth,
    String? profileAvatar,
    String? profileCover,
    File? avatarFile,
  }) async {
    String? token = LocalStorage.getData(key: AppConst.accessToken);
    if (token == null || token.isEmpty) return false;

    try {
      isLoading.value = true;
      Get.dialog(
        const Center(child: CustomAnimationLoader()),
        barrierDismissible: false,
      );

      var avatarUrl = profileAvatar;
      if (avatarFile != null) {
        final uploaded = await MediaService.uploadMedia(
          [avatarFile],
          notifyOnError: false,
        );
        if (uploaded == null || uploaded.isEmpty) {
          if (Get.isDialogOpen ?? false) Get.back();
          isLoading.value = false;
          CustomSnackBar.error(
            message: 'Failed to update profile. Please try again.',
          );
          return false;
        }
        avatarUrl = uploaded.first;
      }

      Map<String, dynamic> body = {
        "name": name,
        "phoneNumber": phone,
        "location": location,
        if (gender != null) "gender": gender.apiValue,
        if (dateOfBirth != null) "dateOfBirth": DateOfBirth.toApi(dateOfBirth),
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          "profileAvatar": avatarUrl,
        if (profileCover != null && profileCover.isNotEmpty)
          "profileCover": profileCover,
      };

      Map<String, dynamic> headers = {
        'Authorization': 'Bearer $token',
      };

      Response response = await BaseClient().patch(
        endpoint: EndPoint.PROFILE,
        body: body,
        headers: headers,
      );

      Get.back(); // close loader
      isLoading.value = false;

      dynamic resData = response.data;
      if (resData != null && resData['success'] == true) {
        userName.value = name;
        userPhone.value = phone;
        userLocation.value = location;
        if (gender != null) userGender.value = gender;
        if (dateOfBirth != null) userDateOfBirth.value = dateOfBirth;
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          userAvatar.value = avatarUrl;
        }

        CustomSnackBar.success(
            message: resData['message'] ?? "Profile updated successfully!");
        return true;
      } else {
        String msg = resData?['message'] ?? "Failed to update profile.";
        CustomSnackBar.error(message: msg);
        return false;
      }
    } catch (e) {
      Get.back();
      isLoading.value = false;
      debugPrint("Update Profile Error: $e");
      CustomSnackBar.error(
          message: "Failed to update profile. Please try again.");
      return false;
    }
  }

  /// Changes User Password via `PATCH /api/v1/change-password`
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty) {
      CustomSnackBar.error(message: "Please enter your current password");
      return false;
    }
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      CustomSnackBar.error(message: "Please fill in all password fields");
      return false;
    }
    if (newPassword != confirmPassword) {
      CustomSnackBar.error(message: "New passwords do not match");
      return false;
    }

    String? token = LocalStorage.getData(key: AppConst.accessToken);
    if (token == null || token.isEmpty) return false;

    try {
      isLoading.value = true;
      Get.dialog(
        const Center(child: CustomAnimationLoader()),
        barrierDismissible: false,
      );

      Map<String, dynamic> body = {
        "currentPassword": currentPassword,
        "newPassword": newPassword,
        "confirmPassword": confirmPassword,
      };

      Map<String, dynamic> headers = {
        'Authorization': 'Bearer $token',
      };

      Response response = await BaseClient().patch(
        endpoint: EndPoint.CHANGE_PASSWORD,
        body: body,
        headers: headers,
      );

      Get.back(); // close loader
      isLoading.value = false;

      dynamic resData = response.data;
      if (resData != null && resData['success'] == true) {
        CustomSnackBar.success(
            message: resData['message'] ?? "Password changed successfully!");
        return true;
      } else {
        String msg = resData?['message'] ?? "Failed to change password.";
        CustomSnackBar.error(message: msg);
        return false;
      }
    } catch (e) {
      Get.back();
      isLoading.value = false;
      debugPrint("Change Password Error: $e");
      CustomSnackBar.error(
          message: "Failed to change password. Please check your credentials.");
      return false;
    }
  }

  late final LogoutFlow _logoutFlow = LogoutFlow(
    store: const LocalAuthTokenStore(),
    deviceIdentifier: DeviceHelper.getDeviceIdentifier,
    post: (body, headers) => BaseClient().post(
      endpoint: EndPoint.LOGOUT,
      body: body,
      headers: headers,
    ),
    onCleared: () async {
      DeepLinkService.instance.onLoggedOut();
      NotificationRouter.onLoggedOut();
    },
  );

  /// Logs out user via `POST /api/v1/auth/logout` (sends the refresh token so
  /// the server revokes the refresh session) and clears local credentials.
  Future<void> logout() async {
    if (isLoading.value) return;

    // Close logout confirmation sheet if open
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }

    isLoading.value = true;
    Get.dialog(
      const Center(child: CustomAnimationLoader()),
      barrierDismissible: false,
    );

    try {
      await _logoutFlow.run();
    } finally {
      if (Get.isDialogOpen ?? false) {
        Get.back(); // close loader
      }
      isLoading.value = false;

      CustomSnackBar.success(message: 'Logged out successfully');
      Get.offAll(() => const LoginView());
    }
  }

  /// Deletes the signed-in account through `DELETE /profile`.
  Future<bool> deleteAccount() async {
    if (isLoading.value) return false;

    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    if (token == null || token.isEmpty) {
      CustomSnackBar.error(message: 'Please sign in again and retry.');
      return false;
    }

    isLoading.value = true;
    try {
      final response = await BaseClient().delete(
        endpoint: EndPoint.DELETE_ACCOUNT,
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = response.data;
      if (data is Map && data['success'] == false) {
        CustomSnackBar.error(
          message: data['message']?.toString() ?? 'Account deletion failed.',
        );
        return false;
      }

      await LocalStorage.removeData(key: AppConst.accessToken);
      await LocalStorage.removeData(key: AppConst.refreshToken);
      await LocalStorage.removeData(key: AppConst.role);
      DeepLinkService.instance.onLoggedOut();
      NotificationRouter.onLoggedOut();
      Get.offAll(() => const LoginView());
      CustomSnackBar.success(message: 'Account deletion request completed.');
      return true;
    } catch (e) {
      debugPrint('Delete account error: $e');
      CustomSnackBar.error(
        message: 'Could not delete your account. Please try again.',
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
