import 'dart:typed_data';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactModel {
  final String id;
  String displayName;
  final String phoneNumber;
  Uint8List? photo;

  // Custom data for Guest Details
  int age = 25;
  String gender = "M"; // M, F or O
  String? imagePath; // Selected from image picker if photo is null

  ContactModel({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.photo,
  });
}

class PhoneContactsController extends GetxController {
  var contactsList = <ContactModel>[].obs;
  var filteredContacts = <ContactModel>[].obs;
  var selectedContacts = <ContactModel>[].obs;

  var isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    isLoading.value = true;
    try {
      if (await Permission.contacts.request().isGranted) {
        List<Contact> contacts = await FlutterContacts.getAll(
          properties: {
            ContactProperty.phone,
            ContactProperty.name,
            ContactProperty.photoThumbnail,
          },
        );

        var parsedContacts = contacts
            .where((c) => c.phones.isNotEmpty)
            .map((c) {
          return ContactModel(
            id: c.id ?? "",
            displayName: _contactName(c),
            phoneNumber: c.phones.first.number,
            photo: c.photo?.thumbnail ?? c.photo?.fullSize,
          );
        }).toList();

        contactsList.assignAll(parsedContacts);
        filteredContacts.assignAll(parsedContacts);
      } else {
        contactsList.clear();
        filteredContacts.clear();
      }
    } catch (e) {
      contactsList.clear();
      filteredContacts.clear();
    } finally {
      isLoading.value = false;
    }
  }

  String _contactName(Contact contact) {
    final display = contact.displayName?.trim() ?? '';
    if (display.isNotEmpty) return display;

    final name = contact.name;
    if (name == null) return '';
    return [
      name.prefix,
      name.first,
      name.middle,
      name.last,
      name.suffix,
      name.nickname,
    ].where((part) => part?.trim().isNotEmpty == true).join(' ');
  }

  void searchContacts(String query) {
    if (query.isEmpty) {
      filteredContacts.assignAll(contactsList);
    } else {
      filteredContacts.assignAll(contactsList.where((c) {
        return c.displayName.toLowerCase().contains(query.toLowerCase()) ||
            c.phoneNumber.contains(query);
      }).toList());
    }
  }

  void addManualContact({required String name, required String phone}) {
    final contact = ContactModel(
      id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
      displayName: name.trim(),
      phoneNumber: phone.trim(),
    );
    contactsList.insert(0, contact);
    filteredContacts.insert(0, contact);
    selectedContacts.add(contact);
    selectedContacts.refresh();
  }

  void toggleSelection(ContactModel contact) {
    if (isSelected(contact)) {
      selectedContacts.removeWhere((element) =>
          (element.id.isNotEmpty && element.id == contact.id) ||
          (element.phoneNumber.isNotEmpty &&
              element.phoneNumber == contact.phoneNumber));
    } else {
      selectedContacts.add(contact);
    }
    selectedContacts.refresh();
  }

  bool isSelected(ContactModel contact) {
    return selectedContacts.any((element) =>
        (element.id.isNotEmpty && element.id == contact.id) ||
        (element.phoneNumber.isNotEmpty &&
            element.phoneNumber == contact.phoneNumber));
  }
}
