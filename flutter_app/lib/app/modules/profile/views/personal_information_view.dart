import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/resources/common_widget/custom_network_image.dart';
import '../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../core/resources/common_widget/custom_button.dart';
import '../../../core/resources/common_widget/custom_date_picker.dart';
import '../../../core/resources/common_widget/custom_drop_down_widget.dart';
import '../../../core/resources/common_widget/custom_text_field.dart';
import '../../../core/resources/app_const/app_const.dart';
import '../../../core/utils/personal_details.dart';

import '../controllers/profile_controller.dart';

class PersonalInfoView extends StatefulWidget {
  const PersonalInfoView({super.key});

  @override
  State<PersonalInfoView> createState() => _PersonalInfoViewState();
}

class _PersonalInfoViewState extends State<PersonalInfoView> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController locationController;
  late TextEditingController dateOfBirthController;

  final controller = Get.find<ProfileController>();
  final ImagePicker _picker = ImagePicker();

  File? _selectedAvatarFile;
  Gender? _selectedGender;
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: controller.userName.value);
    emailController = TextEditingController(text: controller.userEmail.value);
    phoneController = TextEditingController(text: controller.userPhone.value);
    locationController =
        TextEditingController(text: controller.userLocation.value);
    _selectedGender = controller.userGender.value;
    _selectedDateOfBirth = controller.userDateOfBirth.value;
    dateOfBirthController = TextEditingController(
      text: _selectedDateOfBirth == null
          ? ''
          : DateOfBirth.format(_selectedDateOfBirth!),
    );
  }

  Future<void> _pickDateOfBirth() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final lastDate = DateOfBirth.lastDate;
    final picked = await showCustomDatePicker(
      context,
      title: 'Select date of birth',
      initialDate: _selectedDateOfBirth ?? DateTime(lastDate.year - 18),
      firstDate: DateOfBirth.firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateOfBirth = picked;
      dateOfBirthController.text = DateOfBirth.format(picked);
    });
  }

  Future<void> _pickAvatarImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    setState(() {
      _selectedAvatarFile = File(image.path);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationController.dispose();
    dateOfBirthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(title: "Personal Information"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickAvatarImage,
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E1E1E),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: ClipOval(
                        child: _buildAvatarWidget(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAvatarImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCA73A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            CustomTextField(
              label: "Name",
              hint: "Enter your name",
              controller: nameController,
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: "Email",
              hint: "Enter your email",
              controller: emailController,
              readOnly: true, // Email modification rejected by backend
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: "Phone Number",
              hint: "e.g. +39 XXX XXX XXXX",
              controller: phoneController,
            ),
            const SizedBox(height: 20),
            CustomDropDownWidget(
              label: "Gender",
              hintText: "Select gender",
              items: Gender.labels,
              selectedValue: _selectedGender?.label,
              onChanged: (label) {
                setState(() => _selectedGender = Gender.fromLabel(label));
              },
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: "Date of Birth",
              hint: "DD/MM/YYYY",
              controller: dateOfBirthController,
              readOnly: true,
              onTap: _pickDateOfBirth,
              suffixIcon: const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: "Location",
              hint: "Enter location",
              controller: locationController,
            ),
            const SizedBox(height: 40),
            CustomButton(
              title: "Save Changes",
              onTap: () async {
                final existingAvatar = controller.userAvatar.value;
                final success = await controller.updateProfile(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  location: locationController.text.trim(),
                  gender: _selectedGender,
                  dateOfBirth: _selectedDateOfBirth,
                  profileAvatar: _selectedAvatarFile == null
                      ? existingAvatar
                      : null,
                  avatarFile: _selectedAvatarFile,
                );

                if (success) {
                  Get.back();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget() {
    if (_selectedAvatarFile != null) {
      return Image.file(_selectedAvatarFile!, fit: BoxFit.cover);
    }

    if (controller.userAvatar.value.isNotEmpty) {
      return CustomNetworkImage(
        imageUrl: controller.userAvatar.value,
        height: 120,
        width: 120,
      );
    }

    return CustomNetworkImage(
      imageUrl: AppConst.placeHolderImage,
      height: 120,
      width: 120,
    );
  }
}
