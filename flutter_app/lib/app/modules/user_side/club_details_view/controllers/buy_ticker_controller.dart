import '../widgets/waiting_list_panel.dart';
import 'dart:io';
import 'dart:math';

import 'package:bookdianight_app/app/config/flavor_config.dart';
import 'package:bookdianight_app/app/core/network/api_expection.dart';
import 'package:bookdianight_app/app/core/utils/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:bookdianight_app/app/services/media_service.dart';
import '../../booking/controllers/booking_controller.dart';
import '../../booking/repository/booking_repository.dart';
import '../../home/model/club_model.dart';
import '../../../../core/explore/model/event_offer_model.dart';
import '../../../../core/explore/model/explore_api_model.dart';
import '../repository/club_purchase_repository.dart';
import 'phone_contacts_controller.dart';

class BuyTickerController extends GetxController {
  final ClubPurchaseRepository _purchaseRepository = ClubPurchaseRepository();
  final BookingRepository _bookingRepository = BookingRepository();
  final confirmedBookingId = ''.obs;
  final confirmedOrderId = ''.obs;
  final isOpeningTicket = false.obs;
  String _pendingBookingId = '';
  var guestCount = 2.obs;
  final eventFriends = <ContactModel>[].obs;
  DateTime? eventStartAt;
  DateTime? eventEndAt;
  final selectedTicketTier = Rxn<EventTicketTierModel>();
  final promoCodeInput = ''.obs;
  final appliedPromo = Rxn<PromoValidationModel>();
  final promoError = RxnString();
  final isValidatingPromo = false.obs;

  void setEventSchedule(DateTime? start, DateTime? end) {
    eventStartAt = start;
    eventEndAt = end;
  }

  String get eventDateLabel {
    final start = eventStartAt?.toLocal();
    if (start == null) return 'Not available';
    final end = eventEndAt?.toLocal();
    if (end != null &&
        (start.year != end.year ||
            start.month != end.month ||
            start.day != end.day)) {
      return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
    }
    return DateFormat('EEE, MMMM d, yyyy').format(start);
  }

  String get eventStartClock {
    final start = eventStartAt?.toLocal();
    if (start == null) return '--';
    return DateFormat('h:mm a').format(start);
  }

  String get eventEndClock {
    final end = eventEndAt?.toLocal();
    if (end == null) return '';
    return DateFormat('h:mm a').format(end);
  }

  String get eventTimeLabel {
    final start = eventStartAt?.toLocal();
    if (start == null) return '--';
    final startTime = DateFormat('h:mm a').format(start);
    final end = eventEndAt?.toLocal();
    if (end == null) return startTime;
    return '$startTime – ${DateFormat('h:mm a').format(end)}';
  }

  // Real Dynamic Calendar State
  var focusedDate = DateTime.now().obs;
  var selectedDate = DateTime.now().obs;

  /// Wall-clock values in fixed CST (UTC−6), matching the purchase API.
  final clubStart = Rxn<DateTime>();
  final clubEnd = Rxn<DateTime>();
  final intervalRequired = false.obs;
  final openingHours = <ExploreOpeningHourModel>[].obs;

  final serviceCharge = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    final today = todayCst;
    selectedDate.value = today;
    focusedDate.value = today;
    loadServiceCharge();
  }

  Future<void> loadServiceCharge() async {
    try {
      serviceCharge.value = await _purchaseRepository.fetchServiceCharge();
    } catch (_) {}
  }

  String formatEuro(num amount) {
    final value = amount.toDouble();
    if (value == value.roundToDouble()) {
      return '€${value.toStringAsFixed(0)}';
    }
    return '€${value.toStringAsFixed(2)}';
  }

  DateTime get nowCst {
    final utc = DateTime.now().toUtc();
    final shifted = utc.subtract(const Duration(hours: 6));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
    );
  }

  DateTime get todayCst => DateTime(nowCst.year, nowCst.month, nowCst.day);

  static const _weekdayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  bool _sameOpeningHours(List<ExploreOpeningHourModel> hours) {
    if (openingHours.length != hours.length) return false;
    for (var i = 0; i < hours.length; i++) {
      final current = openingHours[i];
      final next = hours[i];
      if (current.dayOfWeek != next.dayOfWeek ||
          current.isClosed != next.isClosed ||
          current.closesNextDay != next.closesNextDay ||
          current.openTime.hour != next.openTime.hour ||
          current.openTime.minute != next.openTime.minute ||
          current.closeTime.hour != next.closeTime.hour ||
          current.closeTime.minute != next.closeTime.minute) {
        return false;
      }
    }
    return true;
  }

  void setClubOpeningHours(List<ExploreOpeningHourModel> hours) {
    if (_sameOpeningHours(hours)) return;
    openingHours.assignAll(hours);
    final start = clubStart.value;
    if (start != null && isClubClosedOn(start)) {
      clubStart.value = null;
      clubEnd.value = null;
      return;
    }
    final end = clubEnd.value;
    if (end != null && isClubClosedOn(end, forEnd: true)) {
      clubEnd.value = null;
    }
  }

  /// API `dayOfWeek`: 0 = Sunday … 6 = Saturday.
  int apiDayOfWeek(DateTime day) => day.weekday % 7;

  ExploreOpeningHourModel? openingHoursFor(DateTime day) {
    if (openingHours.isEmpty) return null;
    final dow = apiDayOfWeek(day);
    for (final hours in openingHours) {
      if (hours.dayOfWeek == dow) return hours;
    }
    return null;
  }

  bool isClubClosedOn(DateTime day, {bool forEnd = false}) {
    if (openingHours.isEmpty) return false;
    final hours = openingHoursFor(day);
    final closed = hours == null || hours.isClosed;
    if (!closed) return false;
    if (!forEnd) return true;
    final previous = day.subtract(const Duration(days: 1));
    return !_closesOvernight(openingHoursFor(previous));
  }

  bool isWeekdayAlwaysClosed(int dartWeekday) {
    if (openingHours.isEmpty) return false;
    final dow = dartWeekday % 7;
    ExploreOpeningHourModel? match;
    for (final hours in openingHours) {
      if (hours.dayOfWeek == dow) {
        match = hours;
        break;
      }
    }
    return match == null || match.isClosed;
  }

  List<String> get closedWeekdayNames {
    if (openingHours.isEmpty) return const [];
    final names = <String>[];
    for (var dow = 0; dow < 7; dow++) {
      ExploreOpeningHourModel? match;
      for (final hours in openingHours) {
        if (hours.dayOfWeek == dow) {
          match = hours;
          break;
        }
      }
      if (match == null || match.isClosed) {
        names.add(_weekdayNames[dow]);
      }
    }
    return names;
  }

  String weekdayName(DateTime day) => _weekdayNames[apiDayOfWeek(day)];

  bool isTimeWithinOpeningHours(DateTime wall) {
    if (openingHours.isEmpty) return true;
    final hours = openingHoursFor(wall);
    if (hours == null || hours.isClosed) {
      final previous = openingHoursFor(wall.subtract(const Duration(days: 1)));
      if (_closesOvernight(previous)) {
        return _minutes(wall) <= _minutes(previous!.closeTime);
      }
      return false;
    }
    final time = _minutes(wall);
    final open = _minutes(hours.openTime);
    final close = _minutes(hours.closeTime);
    if (_closesOvernight(hours)) return time >= open;
    return time >= open && time <= close;
  }

  String openingWindowLabel(DateTime day) {
    final hours = openingHoursFor(day);
    if (hours == null || hours.isClosed) return '';
    final open = clockLabel(hours.openTime);
    final close = clockLabel(hours.closeTime);
    return _closesOvernight(hours) ? '$open – $close (+1 day)' : '$open – $close';
  }

  bool _closesOvernight(ExploreOpeningHourModel? hours) {
    if (hours == null || hours.isClosed) return false;
    if (hours.closesNextDay) return true;
    return _minutes(hours.closeTime) <= _minutes(hours.openTime);
  }

  int _minutes(DateTime value) => value.hour * 60 + value.minute;

  DateTime _clampedEndAfter(DateTime start) {
    final fallback = start.add(const Duration(hours: 2));
    final hours = openingHoursFor(start);
    if (hours == null || hours.isClosed) return fallback;
    if (_closesOvernight(hours)) {
      if (isClubClosedOn(fallback, forEnd: true) &&
          !isTimeWithinOpeningHours(fallback)) {
        return DateTime(
          start.year,
          start.month,
          start.day,
        ).add(Duration(days: 1, minutes: _minutes(hours.closeTime)));
      }
      return fallback;
    }
    final close = DateTime(
      start.year,
      start.month,
      start.day,
      hours.closeTime.hour,
      hours.closeTime.minute,
    );
    if (fallback.isAfter(close)) return close.isAfter(start) ? close : fallback;
    return fallback;
  }

  void setClubStart(DateTime wall) {
    clubStart.value = wall;
    clubEnd.value = _clampedEndAfter(wall);
    intervalRequired.value = false;
  }

  void setClubEnd(DateTime wall) {
    clubEnd.value = wall;
    if (clubStart.value != null && clubEnd.value != null) {
      intervalRequired.value = false;
    }
  }

  String? clubIntervalError() {
    final start = clubStart.value;
    final end = clubEnd.value;
    if (start == null) return 'Start date and time is required.';
    if (end == null) return 'End date and time is required.';
    if (isClubClosedOn(start)) {
      return 'The club is closed on ${weekdayName(start)}. Pick an opening day.';
    }
    if (isClubClosedOn(end, forEnd: true)) {
      return 'The club is closed on ${weekdayName(end)}. Pick an opening day.';
    }
    if (!start.isAfter(nowCst)) {
      return 'Start time has already passed.';
    }
    if (!end.isAfter(start)) {
      return 'End time must be after the start time.';
    }
    if (!isTimeWithinOpeningHours(start)) {
      final window = openingWindowLabel(start);
      return window.isEmpty
          ? 'Start time must be during opening hours.'
          : 'Start time must be during opening hours ($window).';
    }
    if (!isTimeWithinOpeningHours(end)) {
      final window = openingWindowLabel(end);
      return window.isEmpty
          ? 'End time must be during opening hours.'
          : 'End time must be during opening hours ($window).';
    }
    return null;
  }

  String get clubStartIso => _cstIso(clubStart.value!);

  String get clubEndIso => _cstIso(clubEnd.value!);

  String clockLabel(DateTime wall) {
    final hour12 = wall.hour % 12 == 0 ? 12 : wall.hour % 12;
    final minute = wall.minute.toString().padLeft(2, '0');
    final period = wall.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  String dateLabel(DateTime wall) =>
      DateFormat('EEE, MMM d, yyyy').format(wall);

  String get clubDateSummary {
    final start = clubStart.value!;
    final end = clubEnd.value!;
    if (isSameDay(start, end)) {
      return DateFormat('MMMM d, yyyy').format(start);
    }
    return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
  }

  String get clubTimeSummary =>
      '${clockLabel(clubStart.value!)} – ${clockLabel(clubEnd.value!)}';

  String _cstIso(DateTime wall) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${wall.year.toString().padLeft(4, '0')}-'
        '${two(wall.month)}-${two(wall.day)}T'
        '${two(wall.hour)}:${two(wall.minute)}:00.000-06:00';
  }

  void nextMonth() {
    focusedDate.value = DateTime(
      focusedDate.value.year,
      focusedDate.value.month + 1,
      1,
    );
  }

  void previousMonth() {
    final now = todayCst;
    final prev = DateTime(
      focusedDate.value.year,
      focusedDate.value.month - 1,
      1,
    );
    if (prev.year > now.year ||
        (prev.year == now.year && prev.month >= now.month)) {
      focusedDate.value = prev;
    }
  }

  void selectCalendarDate(DateTime date) {
    selectedDate.value = date;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool isPastDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(todayCst);
  }

  // Package selection for Club booking
  var selectedPackageIndex = 1.obs; // Default to VIP Table (index 1)

  final List<Map<String, dynamic>> tablePackages = [
    {
      'title': 'Standard Entry',
      'price': '€80.00',
      'numericPrice': 80.0,
      'capacity': '2—6 guests',
      'features': ['Priority entry', 'Access all areas', 'Welcome drink'],
    },
    {
      'title': 'VIP Table',
      'price': '€160.00',
      'numericPrice': 160.0,
      'capacity': '2—10 guests',
      'features': [
        'Reserved table',
        'Priority entry',
        '1 bottle included',
        'Dedicated host',
      ],
    },
    {
      'title': 'Bottle Package',
      'price': '€240.00',
      'numericPrice': 240.0,
      'capacity': '4—12 guests',
      'features': [
        '2 premium bottles',
        'Mixers included',
        'Reserved sofa area',
        'Priority entry',
        'Dedicated server',
      ],
    },
    {
      'title': 'Birthday Package',
      'price': '€350.00',
      'numericPrice': 350.0,
      'capacity': '6—15 guests',
      'features': [
        '3 premium bottles',
        'Birthday cake',
        'Confetti cannon',
        'VIP area',
        'Photographer',
        'Priority entry',
      ],
    },
  ];

  Map<String, dynamic> get selectedPackage {
    if (selectedPackageIndex.value >= 0 &&
        selectedPackageIndex.value < tablePackages.length) {
      return tablePackages[selectedPackageIndex.value];
    }
    if (tablePackages.isEmpty) return {};
    return tablePackages[0];
  }

  void incrementGuest() {
    guestCount.value++;
  }

  void decrementGuest() {
    if (guestCount.value > 1) {
      guestCount.value--;
    }
  }

  void selectPackage(int index) {
    selectedPackageIndex.value = index;
  }

  final availablePackages = <ClubPackageModel>[].obs;
  final isLoadingPackages = false.obs;
  final isPaying = false.obs;

  String? _heldOrderId;
  String? _heldPackageId;
  String? _heldWindow;
  int? _heldGuests;
  String? _heldPaymentKey;
  DateTime? _heldUntil;

  Future<bool> loadClubPackages(String clubId) async {
    if (clubId.trim().isEmpty) {
      CustomSnackBar.error(message: 'This club cannot be booked yet.');
      return false;
    }
    final intervalError = clubIntervalError();
    if (intervalError != null) {
      intervalRequired.value = clubStart.value == null || clubEnd.value == null;
      CustomSnackBar.warning(message: intervalError);
      return false;
    }
    intervalRequired.value = false;
    isLoadingPackages.value = true;
    try {
      final packages = await _purchaseRepository.fetchAvailability(
        clubId: clubId,
        startAt: clubStartIso,
        endAt: clubEndIso,
        guestCount: guestCount.value,
      );
      availablePackages.assignAll(packages);
      tablePackages
        ..clear()
        ..addAll(packages.map(_packageMap));
      selectedPackageIndex.value = packages.isEmpty ? -1 : 0;
      if (packages.isEmpty) {
        final slotLabel = (clubStart.value != null && clubEnd.value != null)
            ? '${DateFormat('EEE, MMM d · h:mm a').format(clubStart.value!)} – ${DateFormat('h:mm a').format(clubEnd.value!)}'
            : null;
        await Get.bottomSheet<void>(
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: WaitingListPanel(
                  clubId: clubId,
                  canJoin: true,
                  targetSlot: slotLabel,
                  guestCount: guestCount.value,
                  startAt: clubStart.value,
                ),
              ),
            ),
          ),
          backgroundColor: const Color(0xFF0D0D0D),
          isScrollControlled: true,
        );
        return false;
      }
      return true;
    } on ApiException catch (error) {
      CustomSnackBar.error(message: error.message);
      return false;
    } catch (error) {
      CustomSnackBar.error(message: error.toString());
      return false;
    } finally {
      isLoadingPackages.value = false;
    }
  }

  int packageGuestCapacity([Map<String, dynamic>? package]) {
    final selected = package ?? selectedPackage;
    final raw = selected['numericCapacity'];
    if (raw is num && raw > 0) return raw.toInt();
    final matches = RegExp(r'\d+').allMatches('${selected['capacity']}');
    final parsed = matches.isEmpty
        ? null
        : int.tryParse(matches.last.group(0)!);
    if (parsed != null && parsed > 0) return parsed;
    return guestCount.value;
  }

  Map<String, dynamic> _packageMap(ClubPackageModel package) {
    return {
      'id': package.id,
      'title': package.name,
      'price': package.priceLabel,
      'numericPrice': double.tryParse(package.price) ?? 0,
      'capacity': '${package.capacity} guests',
      'numericCapacity': package.capacity,
      'features': package.features,
      'description': package.description,
    };
  }

  void prepareEventGuests(List<ContactModel> friends) {
    eventFriends.assignAll(friends);
    guestCount.value = friends.length + 1;
    clearPromo();
  }

  void selectTicketTier(EventTicketTierModel? tier) {
    selectedTicketTier.value = tier;
    clearPromo();
  }

  double eventUnitPrice(String fallbackPrice) {
    final tier = selectedTicketTier.value;
    if (tier != null) return tier.price;
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(fallbackPrice);
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  double eventSubtotal(String fallbackPrice) {
    return eventUnitPrice(fallbackPrice) * guestCount.value;
  }

  void clearPromo() {
    appliedPromo.value = null;
    promoError.value = null;
  }

  Future<bool> applyPromo({
    required String eventId,
    required double originalAmount,
  }) async {
    final code = promoCodeInput.value.trim();
    if (code.isEmpty) {
      promoError.value = 'Enter a promo code';
      return false;
    }
    if (originalAmount <= 0) {
      promoError.value = 'Add tickets before applying a code';
      return false;
    }
    isValidatingPromo.value = true;
    promoError.value = null;
    try {
      final result = await _purchaseRepository.validatePromo(
        code: code,
        originalAmount: originalAmount,
        eventId: eventId,
      );
      if (!result.isValid) {
        appliedPromo.value = null;
        promoError.value = 'This promo code is not valid';
        return false;
      }
      appliedPromo.value = result;
      return true;
    } catch (error) {
      appliedPromo.value = null;
      promoError.value = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Exception: ', '');
      return false;
    } finally {
      isValidatingPromo.value = false;
    }
  }

  Future<bool> payForEvent(String eventId) async {
    if (isPaying.value) return false;
    if (eventId.trim().isEmpty) {
      CustomSnackBar.error(message: 'This event cannot be booked yet.');
      return false;
    }
    final publishableKey = AppConfig.stripePublishableKey.trim();
    if (publishableKey.isEmpty) {
      CustomSnackBar.error(message: 'Stripe is not configured.');
      return false;
    }

    isPaying.value = true;
    try {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      final friends = <Map<String, dynamic>>[];
      for (final friend in eventFriends) {
        friends.add(await _friendPayload(friend));
      }

      final friendKey = friends
          .map((friend) => '${friend['phoneNumber']}|${friend['name']}')
          .join(',');
      final tierId = selectedTicketTier.value?.id ?? '';
      final promoCode = appliedPromo.value?.code ?? '';
      final window = '$eventId|$tierId|$promoCode|$friendKey';
      final reuseHold =
          _heldOrderId != null &&
          _heldWindow == window &&
          _heldPaymentKey != null &&
          _heldUntil != null &&
          DateTime.now().isBefore(_heldUntil!);

      late final String orderId;
      late final String paymentKey;
      if (reuseHold) {
        orderId = _heldOrderId!;
        paymentKey = _heldPaymentKey!;
      } else {
        paymentKey = _idempotencyKey('pay');
        final purchase = await _purchaseRepository.createEventPurchase(
          eventId: eventId,
          friends: friends,
          idempotencyKey: _idempotencyKey('event'),
          ticketTierId: selectedTicketTier.value?.id,
          promoCode: appliedPromo.value?.code,
        );
        orderId = purchase.orderId;
        _pendingBookingId = purchase.bookingId;
        _heldOrderId = orderId;
        _heldWindow = window;
        _heldPaymentKey = paymentKey;
        _heldUntil = DateTime.now().add(const Duration(minutes: 9));
      }

      final clientSecret = await _purchaseRepository.createPaymentIntent(
        orderId: orderId,
        idempotencyKey: paymentKey,
      );
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'BookdiaNight',
          style: ThemeMode.dark,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      confirmedBookingId.value = _pendingBookingId;
      confirmedOrderId.value = orderId;
      _heldOrderId = null;
      _heldUntil = null;
      _refreshMyBookings();
      return true;
    } on StripeException catch (error) {
      if (error.error.code != FailureCode.Canceled) {
        CustomSnackBar.error(
          message: error.error.localizedMessage ?? 'Payment was not completed.',
        );
      }
      return false;
    } on ApiException catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Payment was not completed.'),
      );
      return false;
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Payment was not completed.'),
      );
      return false;
    } finally {
      isPaying.value = false;
    }
  }

  Future<bool> payForModule({
    required String eventId,
    required String moduleId,
    int quantity = 1,
    int guestCount = 1,
  }) async {
    if (isPaying.value) return false;
    if (eventId.trim().isEmpty || moduleId.trim().isEmpty) {
      CustomSnackBar.error(message: 'This module cannot be booked yet.');
      return false;
    }
    final publishableKey = AppConfig.stripePublishableKey.trim();
    if (publishableKey.isEmpty) {
      CustomSnackBar.error(message: 'Stripe is not configured.');
      return false;
    }
    isPaying.value = true;
    try {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      final paymentKey = _idempotencyKey('pay');
      final purchase = await _purchaseRepository.createModulePurchase(
        eventId: eventId,
        moduleId: moduleId,
        quantity: quantity,
        guestCount: guestCount,
        idempotencyKey: _idempotencyKey('module'),
        promoCode: appliedPromo.value?.code,
      );
      final orderId = purchase.orderId;
      if (orderId.isEmpty) {
        throw StateError('Payment could not be started.');
      }
      _pendingBookingId = purchase.bookingId;
      final clientSecret = await _purchaseRepository.createPaymentIntent(
        orderId: orderId,
        idempotencyKey: paymentKey,
      );
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'BookdiaNight',
          style: ThemeMode.dark,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      confirmedBookingId.value = _pendingBookingId;
      confirmedOrderId.value = orderId;
      _refreshMyBookings();
      return true;
    } on StripeException catch (error) {
      if (error.error.code != FailureCode.Canceled) {
        CustomSnackBar.error(
          message: error.error.localizedMessage ?? 'Payment was not completed.',
        );
      }
      return false;
    } on ApiException catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(
          error,
          'Could not book this module.',
        ),
      );
      return false;
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not book this module.'),
      );
      return false;
    } finally {
      isPaying.value = false;
    }
  }

  Future<Map<String, dynamic>> _friendPayload(ContactModel friend) async {
    final name = friend.displayName.trim();
    final phone = friend.phoneNumber.trim();
    if (name.isEmpty || phone.isEmpty) {
      throw StateError('Each friend needs a name and phone number.');
    }
    final image = await _friendImageUrl(friend);
    return {
      'name': name,
      'phoneNumber': phone,
      'gender': switch (friend.gender) {
        'F' => 'FEMALE',
        'O' => 'OTHER',
        _ => 'MALE',
      },
      'age': friend.age,
      'image': image,
    };
  }

  Future<String> _friendImageUrl(ContactModel friend) async {
    File? file;
    if (friend.imagePath != null && friend.imagePath!.trim().isNotEmpty) {
      file = File(friend.imagePath!);
    } else if (friend.photo != null && friend.photo!.isNotEmpty) {
      final safeId = friend.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      file = File(
        '${Directory.systemTemp.path}/friend_${safeId.isEmpty ? 'guest' : safeId}.jpg',
      );
      await file.writeAsBytes(friend.photo!, flush: true);
    }
    if (file == null || !file.existsSync()) {
      throw StateError('Add a photo for ${friend.displayName}.');
    }
    final urls = await MediaService.uploadMedia([file]);
    final url = (urls != null && urls.isNotEmpty) ? urls.first : '';
    if (url.isEmpty) {
      throw StateError('Could not upload a guest photo.');
    }
    return url;
  }

  Future<bool> payForSelectedClub() async {
    if (isPaying.value) return false;
    final package = selectedPackage;
    final packageId = package['id']?.toString() ?? '';
    if (packageId.isEmpty) {
      CustomSnackBar.error(message: 'Select a package first.');
      return false;
    }
    final publishableKey = AppConfig.stripePublishableKey.trim();
    if (publishableKey.isEmpty) {
      CustomSnackBar.error(message: 'Stripe is not configured.');
      return false;
    }

    isPaying.value = true;
    try {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      final bookedGuests = packageGuestCapacity(package);
      final window = '$clubStartIso|$clubEndIso';
      final reuseHold =
          _heldOrderId != null &&
          _heldPackageId == packageId &&
          _heldWindow == window &&
          _heldGuests == bookedGuests &&
          _heldPaymentKey != null &&
          _heldUntil != null &&
          DateTime.now().isBefore(_heldUntil!);

      late final String orderId;
      late final String paymentKey;
      if (reuseHold) {
        orderId = _heldOrderId!;
        paymentKey = _heldPaymentKey!;
      } else {
        paymentKey = _idempotencyKey('pay');
        final purchase = await _purchaseRepository.createPurchase(
          clubPackageId: packageId,
          startAt: clubStartIso,
          endAt: clubEndIso,
          guestCount: bookedGuests,
          idempotencyKey: _idempotencyKey('club'),
        );
        orderId = purchase.orderId;
        _pendingBookingId = purchase.bookingId;
        _heldOrderId = orderId;
        _heldPackageId = packageId;
        _heldWindow = window;
        _heldGuests = bookedGuests;
        _heldPaymentKey = paymentKey;
        _heldUntil = DateTime.now().add(const Duration(minutes: 9));
      }

      final clientSecret = await _purchaseRepository.createPaymentIntent(
        orderId: orderId,
        idempotencyKey: paymentKey,
      );

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'BookdiaNight',
          style: ThemeMode.dark,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      confirmedBookingId.value = _pendingBookingId;
      confirmedOrderId.value = orderId;
      _heldOrderId = null;
      _heldUntil = null;
      _refreshMyBookings();
      return true;
    } on StripeException catch (error) {
      final code = error.error.code;
      if (code != FailureCode.Canceled) {
        CustomSnackBar.error(
          message: error.error.localizedMessage ?? 'Payment was not completed.',
        );
      }
      return false;
    } on ApiException catch (error) {
      CustomSnackBar.error(message: error.message);
      return false;
    } catch (error) {
      CustomSnackBar.error(message: error.toString());
      return false;
    } finally {
      isPaying.value = false;
    }
  }

  /// Confirmed bookings expose a PDF only when booking detail `ticketState` is READY.
  Future<BookingModel?> openConfirmedTicket(ClubModel club) async {
    if (isOpeningTicket.value) return null;
    isOpeningTicket.value = true;
    try {
      final bookingId = await _resolveBookingId(club);
      if (bookingId.isEmpty) {
        CustomSnackBar.error(
          message:
              'Your booking is confirmed. The ticket is not ready yet. Check My Bookings in a moment.',
        );
        return null;
      }
      final detail = await _bookingRepository.fetchBookingDetail(
        id: bookingId,
        type: club.isEvent ? 'EVENT' : 'CLUB',
      );
      confirmedBookingId.value = detail.id.isEmpty ? bookingId : detail.id;
      if (detail.orderId.trim().isNotEmpty) {
        confirmedOrderId.value = detail.orderId.trim();
      }
      if (!detail.ticketReady) {
        CustomSnackBar.error(
          message:
              'Your booking is confirmed. The ticket PDF is still being prepared.',
        );
        return null;
      }
      return BookingModel(
        club: club.copyWith(
          id: confirmedBookingId.value,
          type: club.isEvent ? 'Event' : 'Club',
        ),
        date: detail.dateLabel,
        time: detail.timeLabel,
        tickets: detail.guestsLabel ?? '--',
        venue: detail.location.trim().isEmpty ? club.location : detail.location,
        price: club.price,
        total: club.price,
        status: BookingStatus.upcoming,
        orderId: confirmedOrderId.value,
        serviceType: club.isEvent ? 'EVENT' : 'CLUB',
      );
    } on ApiException catch (error) {
      CustomSnackBar.error(message: error.message);
      return null;
    } catch (error) {
      debugPrint('Confirmed ticket error: $error');
      CustomSnackBar.error(
        message:
            'Your booking is confirmed, but the ticket could not be opened.',
      );
      return null;
    } finally {
      isOpeningTicket.value = false;
    }
  }

  Future<String> _resolveBookingId(ClubModel club) async {
    final stored = confirmedBookingId.value.trim().isNotEmpty
        ? confirmedBookingId.value.trim()
        : _pendingBookingId.trim();
    if (stored.isNotEmpty) {
      try {
        await _bookingRepository.fetchBookingDetail(
          id: stored,
          type: club.isEvent ? 'EVENT' : 'CLUB',
        );
        return stored;
      } catch (error) {
        debugPrint('Stored booking id did not open a ticket: $error');
      }
    }

    final response = await _bookingRepository.fetchBookings(
      tab: 'UPCOMING',
      page: 1,
      limit: 10,
    );
    final wanted = club.title.trim().toLowerCase();
    for (final item in response.data) {
      final sameName = item.name.trim().toLowerCase() == wanted;
      final sameType = club.isEvent
          ? item.type.toUpperCase() == 'EVENT'
          : item.type.toUpperCase() == 'CLUB';
      if (sameName && sameType && item.id.trim().isNotEmpty) {
        return item.id.trim();
      }
    }
    return '';
  }

  void _refreshMyBookings() {
    if (!Get.isRegistered<BookingController>()) return;
    Get.find<BookingController>().fetchBookings(refresh: true);
  }

  String _idempotencyKey(String prefix) {
    final random = Random().nextInt(1 << 32).toRadixString(16);
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$random';
  }
}
