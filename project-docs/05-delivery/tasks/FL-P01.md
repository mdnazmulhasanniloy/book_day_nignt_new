# FL-P01: Flutter date-of-birth picker (P0.1, Flutter part)

| Field | Value |
|---|---|
| Stack | flutter |
| Milestone | M8-early |
| CR / BUG IDs | P0.1, CR-01 (Flutter part) |
| Depends on | none for the picker fix; collecting a missing DOB for social sign-in depends on backend T-009 (not in this task) |
| Size | at most half a day |
| Status | gap fixed and unit/widget-tested in Docker on branch `fix/flutter-dob-picker` (commit 02e432b); NOT verified on a device; the originally reported picker defect was NOT reproduced |

Branch: from `main` (`fix/flutter-dob-picker`) once the Flutter SDK is available.

## What the code does today (verified by reading)

- Sign-up picks DOB in `sign_up_controller.dart` `pickDateOfBirth`, using the shared `showCustomDatePicker` (`core/resources/common_widget/custom_date_picker.dart`, dark theme) with `firstDate: 1900-01-01`, `lastDate: today`, `initialDate: selected ?? Jan 1 of (this year - 18)`. `DateOfBirth` (`core/utils/personal_details.dart`) formats `dd/MM/yyyy` and sends UTC-midnight ISO (`toApi`).
- Backend `assertSignupDob` (unit tested) rejects future dates, impossible dates and age below `MIN_SIGNUP_AGE = 18`.
- Gap found by reading: the picker allows any date up to today, so a user can pick an under-18 date and only learn from the server error after submitting. `lastDate` should be today minus 18 years.
- Other pickers (`add_event_view`, `add_promo_view`) call `showDatePicker` directly. Follow the shared picker's look.
- Social sign-in creates no DOB (backend, T-009), so there is no Flutter DOB screen for it yet: out of scope here.
- The reported picker defect could not be reproduced by reading; reproduce on a device first.

## Plan

1. Add `DateOfBirth.latestAllowed(DateTime now)` = today minus 18 years (calendar-correct, handles 29 Feb) and use it as `lastDate`; `initialDate` = the selected value if it is not after `latestAllowed`, else `latestAllowed`.
2. Add `DateOfBirth.isAdult(DateTime dob, DateTime now)` and validate in `sign_up_controller` before submit with an inline message ("You must be at least 18"), keeping all entered fields on error.
3. Keep the sent format unchanged (`toApi`), so the backend contract is untouched.
4. Use one named constant mirroring backend `MIN_SIGNUP_AGE`, not a second literal 18.

## Done when

- [ ] Unit tests in `test/`: `latestAllowed` on 29 Feb, month ends and leap years; `isAdult` on the birthday itself and the day before; `toApi` unchanged.
- [ ] Controller test: picker `lastDate` equals `latestAllowed`; an under-18 value is rejected inline with form data kept.
- [ ] `flutter analyze` clean, `flutter test` green; manual run on a device.
- [ ] No backend change.

## Open question (not blocking this task)

Is 18 the product rule for every role, including CLUB_OWNER? The backend applies `MIN_SIGNUP_AGE` to all signups; confirm with the client before changing.

## Implementation status (2026-11-22)

Reproduction in Docker (widget test on the real `showCustomDatePicker` with the real arguments, plus a Dart port of backend `assertSignupDob`):

- Reproduced: the picker offered the current year, and `lastDate` (today) converted by `toApi` is rejected by the backend (age 0 is below `MIN_SIGNUP_AGE = 18`). Both repro tests failed on the unmodified code.
- Not reproduced: no crash or wrong value for 29 Feb, for `toApi` around midnight in a non-UTC timezone (it uses the date components only), or on the today boundary. The originally reported defect is therefore still unknown; only the under-18 gap was confirmed.
- Extra edge found while porting the backend rule: the backend measures age on the UTC date, so a naive local-date cutoff can be rejected for users ahead of UTC, and `DateTime(year - 18, 2, 29)` rolls over to 1 March. `DateOfBirth.latestAllowed` uses the UTC date and maps 29 Feb to 28 Feb.

Fix: `DateOfBirth.minSignupAge = 18` (mirrors backend `MIN_SIGNUP_AGE`), `latestAllowed`, `isOldEnough`, `validate`; `lastDate = latestAllowed`; `initialDate = selected ?? lastDate`; inline error on the DOB field (and on submit) with all entered form data kept; `toApi` unchanged. Helper names differ from the plan above (`isOldEnough`, `validate` instead of `isAdult`). 12 tests in `flutter_app/test/dob_test.dart`. `flutter analyze` unchanged from baseline (34 issues); `flutter test` 42 pass, 1 pre-existing failure (template widget test). No controller-level test (the GetX controller needs platform services), so the inline error wiring is untested.
