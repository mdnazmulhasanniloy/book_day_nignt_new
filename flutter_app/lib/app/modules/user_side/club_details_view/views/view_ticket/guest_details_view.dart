import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../../home/controllers/club_controller.dart';
import '../../controllers/phone_contacts_controller.dart';
import 'booking_summary_view.dart';

class GuestDetailsView extends StatefulWidget {
  final ClubModel clubModel;

  const GuestDetailsView({super.key, required this.clubModel});

  @override
  State<GuestDetailsView> createState() => _GuestDetailsViewState();
}

class _GuestDetailsViewState extends State<GuestDetailsView> {
  final PhoneContactsController controller = Get.find();
  final ImagePicker _picker = ImagePicker();
  final Map<String, TextEditingController> _ageControllers = {};

  TextEditingController _ageController(ContactModel contact) {
    final key = contact.id.isNotEmpty ? contact.id : contact.phoneNumber;
    return _ageControllers.putIfAbsent(
      key,
      () => TextEditingController(text: '${contact.age}'),
    );
  }

  @override
  void dispose() {
    for (final ageController in _ageControllers.values) {
      ageController.dispose();
    }
    super.dispose();
  }

  Future<void> _editName(ContactModel contact) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _EditNameDialog(
        initialName: contact.displayName,
        onSave: (name) {
          contact.displayName = name;
          controller.selectedContacts.refresh();
          if (mounted) setState(() {});
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  Future<void> _pickImage(ContactModel contact) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        contact.imagePath = image.path;
      });
    }
  }

  bool _isAllComplete() {
    // Basic logic: Just check if image exists (from contact or picked)
    // and age is valid. Let's assume default age 25 is valid.
    return controller.selectedContacts.every(
        (c) => c.photo != null || c.imagePath != null);
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0D0D0D);
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);
    const Color primaryPink = Color(0xFFB13271); // Female
    const Color primaryBlue = Color(0xFF2E65B5); // Male

    bool isComplete = _isAllComplete();
    int totalGuests = controller.selectedContacts.length;
    int completedGuests = controller.selectedContacts
        .where((c) => c.photo != null || c.imagePath != null)
        .length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const CustomAppBar(
        title: 'Guest Details',
        backgroundColor: bgColor,
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20.0, vertical: 12.0),
              child: CustomButton(
                title: isComplete
                    ? 'Continue'
                    : 'Complete all guests ($completedGuests/$totalGuests)',
                buttonColor: isComplete ? primaryYellow : const Color(0xFF222222),
                isGradient: false,
                borderRadius: 16,
                paddingVertical: 14,
                titleColor: isComplete ? Colors.black : Colors.grey,
                onTap: isComplete
                    ? () {
                        Get.to(() => BookingSummaryView(
                              clubModel: widget.clubModel,
                              isSingleTicket: false,
                            ));
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: controller.selectedContacts.length,
        itemBuilder: (context, index) {
          final contact = controller.selectedContacts[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 24,
                      width: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF222222),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: CustomText(
                        text: "${index + 1}",
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            text: contact.displayName.trim().isEmpty
                                ? 'Add name'
                                : contact.displayName,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: contact.displayName.trim().isEmpty
                                ? Colors.grey
                                : Colors.white,
                            maxLine: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          CustomText(
                            text: contact.phoneNumber,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey,
                            maxLine: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editName(contact),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: primaryYellow,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Image Picker
                    GestureDetector(
                      onTap: () => _pickImage(contact),
                      child: Container(
                        height: 48,
                        width: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(8),
                          image: _getImage(contact),
                        ),
                        child: (contact.photo == null && contact.imagePath == null)
                            ? const Icon(Icons.image_outlined,
                                color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      flex: 2,
                      child: TextField(
                          controller: _ageController(contact),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF222222),
                            prefixText: 'Age: ',
                            prefixStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: primaryYellow,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            final ageStr = val.replaceAll(RegExp(r'[^0-9]'), '');
                            if (ageStr.isNotEmpty) {
                              contact.age = int.tryParse(ageStr) ?? contact.age;
                            }
                          },
                        ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const CustomText(
                  text: 'Gender',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _genderOption(
                        contact, "M", "Male", Icons.male, primaryBlue),
                    const SizedBox(width: 8),
                    _genderOption(
                        contact, "F", "Female", Icons.female, primaryPink),
                    const SizedBox(width: 8),
                    _genderOption(contact, "O", "Other", Icons.transgender,
                        _otherGenderColor),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _genderOption(
    ContactModel contact,
    String code,
    String label,
    IconData icon,
    Color activeColor,
  ) {
    final selected = contact.gender == code;
    final fg = selected ? activeColor : Colors.white60;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => contact.gender = code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.15)
                : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? activeColor : Colors.white10,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: CustomText(
                  text: label,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                  maxLine: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Color _otherGenderColor = Color(0xFF9B6BE0);

  DecorationImage? _getImage(ContactModel contact) {
    if (contact.imagePath != null) {
      return DecorationImage(
        image: FileImage(File(contact.imagePath!)),
        fit: BoxFit.cover,
      );
    } else if (contact.photo != null) {
      return DecorationImage(
        image: MemoryImage(contact.photo!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName, required this.onSave});

  final String initialName;
  final ValueChanged<String> onSave;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onSave(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CustomText(
                text: 'Edit name',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF222222),
                  hintText: 'Enter name',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDCA73A)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                title: 'Save',
                buttonColor: const Color(0xFFDCA73A),
                isGradient: false,
                borderRadius: 16,
                paddingVertical: 14,
                titleColor: Colors.black,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
