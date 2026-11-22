import 'package:intl/intl.dart';

enum Gender {
  male(label: 'Male', apiValue: 'MALE'),
  female(label: 'Female', apiValue: 'FEMALE'),
  other(label: 'Other', apiValue: 'OTHER');

  const Gender({required this.label, required this.apiValue});

  final String label;
  final String apiValue;

  static List<String> get labels =>
      Gender.values.map((gender) => gender.label).toList(growable: false);

  static Gender? fromLabel(String? label) {
    for (final gender in Gender.values) {
      if (gender.label == label) return gender;
    }
    return null;
  }

  static Gender? fromApi(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final gender in Gender.values) {
      if (gender.apiValue == normalized) return gender;
    }
    return null;
  }
}

class DateOfBirth {
  DateOfBirth._();

  static final DateFormat _displayFormat = DateFormat('dd/MM/yyyy');

  static DateTime get firstDate => DateTime(1900);

  static DateTime get lastDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String format(DateTime date) => _displayFormat.format(date);

  /// Sent as UTC midnight so the calendar day doesn't shift across timezones.
  static String toApi(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).toIso8601String();

  static DateTime? fromApi(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    final utc = parsed.toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }
}
