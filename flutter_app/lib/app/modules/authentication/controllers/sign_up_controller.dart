import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/location/auth_coordinates.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:bookdianight_app/app/core/utils/custom_snack_bar.dart';
import 'package:bookdianight_app/app/core/utils/device_helper.dart';
import 'package:bookdianight_app/app/core/utils/personal_details.dart';
import 'package:bookdianight_app/app/core/resources/common_widget/custom_date_picker.dart';
import 'package:bookdianight_app/app/services/notification_services.dart';
import 'package:bookdianight_app/app/modules/authentication/auth_repository/auth_repository.dart';
import 'package:bookdianight_app/app/modules/authentication/model/sign_up_model.dart';
import 'package:bookdianight_app/app/modules/authentication/views/otp_verification_view.dart';
import 'package:bookdianight_app/app/modules/user_side/home/model/current_location_model.dart';
import 'package:bookdianight_app/app/modules/user_side/home/repository/location_repository.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignUpController extends GetxController {
  final AuthRepository _authRepo = AuthRepository();
  final LocationRepository _locationRepository = LocationRepository();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();

  final List<String> roles = SignUpRole.values
      .map((role) => role.label)
      .toList(growable: false);
  final selectedRole = SignUpRole.user.obs;

  final List<String> genders = Gender.labels;
  final selectedGender = Rxn<Gender>();
  DateTime? selectedDateOfBirth;
  final RxnString dobError = RxnString();

  void onRoleChanged(String? label) {
    if (label == null) return;
    selectedRole.value = SignUpRole.fromLabel(label);
  }

  void onGenderChanged(String? label) {
    selectedGender.value = Gender.fromLabel(label);
  }

  Future<void> pickDateOfBirth(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final lastDate = DateOfBirth.lastDate;
    final picked = await showCustomDatePicker(
      context,
      title: 'Select date of birth',
      initialDate: selectedDateOfBirth ?? lastDate,
      firstDate: DateOfBirth.firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    selectedDateOfBirth = picked;
    dateOfBirthController.text = DateOfBirth.format(picked);
    dobError.value = DateOfBirth.validate(picked);
  }

  var isLoading = false.obs;
  var isLocationLoading = false.obs;
  CurrentLocationModel? currentLocation;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      useCurrentLocation();
    });
  }

  Future<void> useCurrentLocation({bool showError = false}) async {
    if (isLocationLoading.value) return;

    isLocationLoading.value = true;
    final location = await _locationRepository.getCurrentLocation();
    isLocationLoading.value = false;
    currentLocation = location;

    if (location.isAvailable) {
      locationController.text = location.address;
      await LocalStorage.saveData(
        key: AppConst.currentLocation,
        data: location.toJson(),
      );
      return;
    }

    if (showError) {
      CustomSnackBar.warning(message: _locationMessage(location.status));
    }
  }

  String _locationMessage(LocationAccessStatus status) {
    switch (status) {
      case LocationAccessStatus.serviceDisabled:
        return 'Please turn on location services and try again.';
      case LocationAccessStatus.permissionDeniedForever:
        return 'Location permission is disabled. Enable it from app settings.';
      case LocationAccessStatus.permissionDenied:
        return 'Location permission was denied.';
      case LocationAccessStatus.unavailable:
        return 'Current location is unavailable. Please try again.';
      case LocationAccessStatus.available:
        return '';
    }
  }

  Future<void> signUp() async {
    if (isLoading.value) return;

    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String phone = phoneController.text.trim();
    String password = passwordController.text;
    String confirmPassword = confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      CustomSnackBar.error(message: "Please fill all required fields");
      return;
    }

    if (!GetUtils.isEmail(email)) {
      CustomSnackBar.error(message: "Please enter a valid email address");
      return;
    }

    final gender = selectedGender.value;
    if (gender == null) {
      CustomSnackBar.error(message: "Please select your gender");
      return;
    }

    final dateOfBirth = selectedDateOfBirth;
    final dobMessage = DateOfBirth.validate(dateOfBirth);
    if (dateOfBirth == null || dobMessage != null) {
      // Inline on the field; every other entered value is kept.
      dobError.value = dobMessage;
      return;
    }
    dobError.value = null;

    if (password != confirmPassword) {
      CustomSnackBar.error(message: "Passwords do not match");
      return;
    }

    // Close the keyboard and TextField selection toolbar before async work or
    // navigation. Keeping its follower overlay alive while another overlay is
    // inserted can trigger RenderFollowerLayer layout assertions.
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;

    isLoading.value = true;
    try {
      String deviceId = DeviceHelper.getDeviceIdentifier();
      final fcmToken = await NotificationService().currentToken();

      if (currentLocation?.isAvailable != true) {
        await useCurrentLocation();
      }

      if (locationController.text.trim().isEmpty) {
        CustomSnackBar.error(
          message: 'Allow location access or enter your location manually.',
        );
        return;
      }

      final coords = await AuthCoordinates.read();
      final request = SignUpRequestModel(
        role: selectedRole.value.apiValue,
        name: name,
        email: email,
        phoneNumber: phone,
        location: locationController.text.trim(),
        password: password,
        deviceIdentifier: deviceId,
        fcmToken: fcmToken,
        latitude: currentLocation?.latitude ?? coords.lat,
        longitude: currentLocation?.longitude ?? coords.lng,
        platform: DeviceHelper.getPlatform(),
        gender: gender.apiValue,
        dateOfBirth: DateOfBirth.toApi(dateOfBirth),
      );

      final response = await _authRepo.signUp(request);

      if (response.success) {
        final token = response.data?.verificationToken;
        if (token != null) {
          await LocalStorage.saveData(
            key: AppConst.verificationToken,
            data: token,
          );
        }

        CustomSnackBar.success(
          message: response.message.isNotEmpty
              ? response.message
              : 'Signup successful. Check your email for OTP.',
        );

        Get.to(
          () => OtpVerificationView(comeFromSignUp: true),
          arguments: email,
        );
      } else {
        CustomSnackBar.error(
          message: response.message.isNotEmpty
              ? response.message
              : 'Signup failed. Please try again.',
        );
      }
    } catch (e) {
      debugPrint("SignUp Error: $e");
      CustomSnackBar.error(message: e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void goToSignIn() {
    Get.back();
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    dateOfBirthController.dispose();
    super.onClose();
  }
}
