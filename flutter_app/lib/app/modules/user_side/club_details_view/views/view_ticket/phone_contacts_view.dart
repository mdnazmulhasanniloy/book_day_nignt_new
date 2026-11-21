import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../home/controllers/club_controller.dart';
import '../../controllers/phone_contacts_controller.dart';
import 'guest_details_view.dart';

class PhoneContactsView extends StatelessWidget {
  final ClubModel clubModel;

  const PhoneContactsView({super.key, required this.clubModel});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PhoneContactsController());
    const Color bgColor = Color(0xFF0D0D0D);
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const CustomAppBar(
        title: 'Phone Contacts',
        backgroundColor: bgColor,
      ),
      bottomNavigationBar: Obx(() {
        bool hasSelection = controller.selectedContacts.isNotEmpty;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 12.0),
                child: CustomButton(
                  title: hasSelection
                      ? 'Continue With ${controller.selectedContacts.length} Numbers'
                      : 'Select contacts to continue',
                  buttonColor:
                      hasSelection ? primaryYellow : const Color(0xFF222222),
                  isGradient: false,
                  borderRadius: 16,
                  paddingVertical: 14,
                  titleColor: hasSelection ? Colors.black : Colors.grey,
                  onTap: hasSelection
                      ? () {
                          Get.to(() => GuestDetailsView(clubModel: clubModel));
                        }
                      : null,
                ),
              ),
            ],
          ),
        );
      }),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: CustomTextField(
              hint: "Search by name or number...",
              hintColor: Colors.grey,
              filled: true,
              fillColor: cardBgColor,
              isBorder: false,
              borderRadius: 30,
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              onChanged: controller.searchContacts,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => _showManualContactDialog(context, controller),
                icon: const Icon(Icons.person_add_alt_1, color: primaryYellow, size: 18),
                label: const CustomText(
                  text: 'Add manually',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryYellow,
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryYellow),
                );
              }

              if (controller.filteredContacts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: CompactEmptyState.stacked(
                      icon: Icons.contacts_outlined,
                      title: 'No contacts found',
                      message: 'Add a guest manually to continue.',
                      action: CustomButton(
                        title: 'Add manually',
                        buttonColor: primaryYellow,
                        titleColor: Colors.black,
                        isGradient: false,
                        borderRadius: 16,
                        paddingVertical: 12,
                        width: 180,
                        onTap: () =>
                            _showManualContactDialog(context, controller),
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.filteredContacts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final contact = controller.filteredContacts[index];

                  return Obx(() {
                    bool isSelected = controller.isSelected(contact);

                    return GestureDetector(
                      onTap: () => controller.toggleSelection(contact),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isSelected ? primaryYellow : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 24,
                              width: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryYellow
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryYellow
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.black)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF261D0A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.phone_outlined,
                                color: primaryYellow,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (contact.displayName.trim().isNotEmpty)
                                    CustomText(
                                      text: contact.displayName,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      maxLine: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  CustomText(
                                    text: contact.phoneNumber,
                                    fontSize: contact.displayName
                                            .trim()
                                            .isEmpty
                                        ? 14
                                        : 12,
                                    fontWeight: contact.displayName
                                            .trim()
                                            .isEmpty
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: contact.displayName.trim().isEmpty
                                        ? Colors.white
                                        : Colors.grey,
                                    maxLine: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

Future<void> _showManualContactDialog(
  BuildContext context,
  PhoneContactsController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ManualContactDialog(
      onSave: (name, phone) {
        controller.addManualContact(name: name, phone: phone);
        Navigator.pop(dialogContext);
      },
    ),
  );
}

class _ManualContactDialog extends StatefulWidget {
  const _ManualContactDialog({required this.onSave});

  final void Function(String name, String phone) onSave;

  @override
  State<_ManualContactDialog> createState() => _ManualContactDialogState();
}

class _ManualContactDialogState extends State<_ManualContactDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Name and phone number are required.');
      return;
    }
    widget.onSave(name, phone);
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFDCA73A);
    return Dialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
              text: 'Add guest',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _nameController,
              hint: 'Name',
              filled: true,
              fillColor: const Color(0xFF222222),
              isBorder: false,
              borderRadius: 12,
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _phoneController,
              hint: 'Phone number',
              keyboardType: TextInputType.phone,
              filled: true,
              fillColor: const Color(0xFF222222),
              isBorder: false,
              borderRadius: 12,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              CustomText(
                text: _error!,
                fontSize: 12,
                color: const Color(0xFFFF6B6B),
              ),
            ],
            const SizedBox(height: 16),
            CustomButton(
              title: 'Add',
              buttonColor: gold,
              titleColor: Colors.black,
              isGradient: false,
              borderRadius: 12,
              paddingVertical: 12,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
