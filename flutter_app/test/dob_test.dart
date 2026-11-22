import 'package:bookdianight_app/app/core/resources/common_widget/custom_date_picker.dart';
import 'package:bookdianight_app/app/core/utils/personal_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Port of backend assertSignupDob / ageInYears
/// (backend/server/src/app/utils/dob.utils.ts, MIN_SIGNUP_AGE = 18).
bool backendAccepts(String iso, DateTime nowUtc) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T').firstMatch(iso)!;
  final birth = DateTime.parse(iso).toUtc();
  if (birth.year != int.parse(m[1]!) ||
      birth.month != int.parse(m[2]!) ||
      birth.day != int.parse(m[3]!)) {
    return false;
  }
  if (birth.isAfter(nowUtc)) return false;
  var age = nowUtc.year - birth.year;
  final monthDelta = nowUtc.month - birth.month;
  if (monthDelta < 0 || (monthDelta == 0 && nowUtc.day < birth.day)) age -= 1;
  return age >= 18;
}

void main() {
  group('DateOfBirth.latestAllowed', () {
    test('is today minus 18 years', () {
      expect(
        DateOfBirth.latestAllowed(now: DateTime.utc(2026, 11, 22, 12)),
        DateTime(2008, 11, 22),
      );
    });

    test('Feb 29 today maps to Feb 28 (target year has no leap day)', () {
      expect(
        DateOfBirth.latestAllowed(now: DateTime.utc(2028, 2, 29)),
        DateTime(2010, 2, 28),
      );
      expect(DateOfBirth.isOldEnough(DateTime(2010, 3, 1), now: DateTime.utc(2028, 2, 29)), isFalse);
      expect(DateOfBirth.isOldEnough(DateTime(2010, 2, 28), now: DateTime.utc(2028, 2, 29)), isTrue);
    });

    test('uses the UTC date like the backend (UTC+10 morning)', () {
      // 2026-01-02 08:00 in UTC+10 is 2026-01-01 22:00 UTC.
      final now = DateTime.parse('2026-01-02T08:00:00+10:00');
      expect(DateOfBirth.latestAllowed(now: now), DateTime(2008, 1, 1));
      expect(backendAccepts(DateOfBirth.toApi(DateOfBirth.latestAllowed(now: now)), now.toUtc()), isTrue);
      // A local-date cutoff (2008-01-02) would have been rejected by the backend.
      expect(backendAccepts(DateOfBirth.toApi(DateTime(2008, 1, 2)), now.toUtc()), isFalse);
    });

    test('agrees with the backend rule for many dates (latest ok, next day rejected)', () {
      var d = DateTime.utc(2023, 12, 20);
      for (var i = 0; i < 900; i++) {
        final latest = DateOfBirth.latestAllowed(now: d);
        expect(backendAccepts(DateOfBirth.toApi(latest), d), isTrue, reason: '$d latest $latest');
        final next = DateTime(latest.year, latest.month, latest.day + 1);
        expect(backendAccepts(DateOfBirth.toApi(next), d), isFalse, reason: '$d next $next');
        expect(DateOfBirth.isOldEnough(latest, now: d), isTrue);
        expect(DateOfBirth.isOldEnough(next, now: d), isFalse);
        d = d.add(const Duration(days: 1));
      }
    });
  });

  group('isOldEnough / validate', () {
    final now = DateTime.utc(2026, 11, 22, 9);

    test('birthday boundary', () {
      expect(DateOfBirth.isOldEnough(DateTime(2008, 11, 22), now: now), isTrue);
      expect(DateOfBirth.isOldEnough(DateTime(2008, 11, 23), now: now), isFalse);
    });

    test('today and future are under 18', () {
      expect(DateOfBirth.isOldEnough(DateTime(2026, 11, 22), now: now), isFalse);
      expect(DateOfBirth.isOldEnough(DateTime(2030, 1, 1), now: now), isFalse);
    });

    test('born on Feb 29 turns 18 on Mar 1 in a non-leap year (backend rule)', () {
      final dob = DateTime(2000, 2, 29);
      expect(DateOfBirth.isOldEnough(dob, now: DateTime.utc(2018, 2, 28)), isFalse);
      expect(DateOfBirth.isOldEnough(dob, now: DateTime.utc(2018, 3, 1)), isTrue);
    });

    test('validate messages', () {
      expect(DateOfBirth.validate(null, now: now), 'Please select your date of birth');
      expect(DateOfBirth.validate(DateTime(2015, 5, 5), now: now), 'You must be at least 18 years old to sign up');
      expect(DateOfBirth.validate(DateTime(1990, 5, 5), now: now), isNull);
    });
  });

  group('toApi (format unchanged)', () {
    test('leap day', () {
      expect(DateOfBirth.toApi(DateTime(2000, 2, 29)), '2000-02-29T00:00:00.000Z');
    });

    test('time of day never shifts the calendar day', () {
      for (final t in [
        DateTime(1995, 6, 15, 0, 0, 1),
        DateTime(1995, 6, 15, 12),
        DateTime(1995, 6, 15, 23, 59, 59),
      ]) {
        expect(DateOfBirth.toApi(t), '1995-06-15T00:00:00.000Z');
      }
    });

    test('round trip with fromApi', () {
      final dob = DateTime(2000, 2, 29);
      expect(DateOfBirth.fromApi(DateOfBirth.toApi(dob)), dob);
    });
  });

  testWidgets('real picker: newest selectable year is today minus 18 and it can be picked', (tester) async {
    final lastDate = DateOfBirth.lastDate;
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showCustomDatePicker(
                  context,
                  title: 'Select date of birth',
                  initialDate: lastDate,
                  firstDate: DateOfBirth.firstDate,
                  lastDate: lastDate,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    final newest = find.text('${lastDate.year}');
    await tester.scrollUntilVisible(newest, 200, scrollable: find.byType(Scrollable).last);
    expect(newest, findsOneWidget);
    expect(find.text('${lastDate.year + 1}'), findsNothing);
    await tester.tap(newest);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(picked, isNotNull);
    expect(DateOfBirth.isOldEnough(picked!), isTrue);
  });
}
