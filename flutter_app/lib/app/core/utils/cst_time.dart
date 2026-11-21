/// Fixed CST (UTC−6) wall-clock used by club opening hours and purchases.
String cstWallIso(DateTime wall) {
  final clock = wall.isUtc ? wall.toLocal() : wall;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${clock.year.toString().padLeft(4, '0')}-'
      '${two(clock.month)}-${two(clock.day)}T'
      '${two(clock.hour)}:${two(clock.minute)}:00.000-06:00';
}

/// Club opening hours. The API validates bookings by comparing the booking's
/// CST wall clock with the stored clock digits, but converts zoned values to
/// UTC before storing them. Sending the CST digits with a `Z` suffix keeps
/// them unchanged.
String clubClockIso(DateTime wall) {
  final clock = wall.isUtc ? wall.toLocal() : wall;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${clock.year.toString().padLeft(4, '0')}-'
      '${two(clock.month)}-${two(clock.day)}T'
      '${two(clock.hour)}:${two(clock.minute)}:00.000Z';
}

/// Reads the stored opening-hour clock digits as the CST wall clock,
/// ignoring any zone suffix (see [clubClockIso]).
DateTime clubClockFromIso(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  final match = RegExp(r'[T ](\d{2}):(\d{2})').firstMatch(raw) ??
      RegExp(r'^(\d{2}):(\d{2})').firstMatch(raw);
  if (match == null) return DateTime(1970);
  return DateTime(1970, 1, 1, int.parse(match.group(1)!),
      int.parse(match.group(2)!));
}

const _cstOffset = Duration(hours: -6);
final _zonedIso = RegExp(r'T\d{2}:\d{2}.*(Z|[+-]\d{2}:?\d{2})$');

/// Returns the CST wall clock for an ISO value. The API may echo back the
/// value we sent (`...-06:00`) or the same instant in UTC (`...Z`), so zoned
/// values are converted to CST before reading the clock numbers.
DateTime cstWallFromIso(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (_zonedIso.hasMatch(raw)) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final cst = parsed.toUtc().add(_cstOffset);
      return DateTime(cst.year, cst.month, cst.day, cst.hour, cst.minute);
    }
  }
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})',
  ).firstMatch(raw);
  if (match != null) {
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    );
  }
  return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
