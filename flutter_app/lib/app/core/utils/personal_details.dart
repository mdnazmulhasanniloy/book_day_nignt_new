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

  /// Mirrors the backend MIN_SIGNUP_AGE (backend/server/src/const.ts).
  static const int minSignupAge = 18;

  /// Latest date of birth the backend accepts: [minSignupAge] years before
  /// today. The backend measures age on the UTC calendar date, so [now] is
  /// converted to UTC; a local date ahead of UTC could otherwise be rejected.
  /// Feb 29 maps to Feb 28 when the target year is not a leap year.
  static DateTime latestAllowed({DateTime? now}) {
    final utc = (now ?? DateTime.now()).toUtc();
    final year = utc.year - minSignupAge;
    final day = (utc.month == 2 && utc.day == 29 && !_isLeapYear(year))
        ? 28
        : utc.day;
    return DateTime(year, utc.month, day);
  }

  static DateTime get lastDate => latestAllowed();

  static bool _isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// Same rule as the backend assertSignupDob: not in the future and at least
  /// [minSignupAge] years old (calendar-correct, birthday counted).
  static bool isOldEnough(DateTime dob, {DateTime? now}) {
    final today = (now ?? DateTime.now()).toUtc();
    var age = today.year - dob.year;
    final monthDelta = today.month - dob.month;
    if (monthDelta < 0 || (monthDelta == 0 && today.day < dob.day)) age -= 1;
    return age >= minSignupAge;
  }

  /// Inline validation message, or null when [dob] is acceptable.
  static String? validate(DateTime? dob, {DateTime? now}) {
    if (dob == null) return 'Please select your date of birth';
    if (!isOldEnough(dob, now: now)) {
      return 'You must be at least $minSignupAge years old to sign up';
    }
    return null;
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
