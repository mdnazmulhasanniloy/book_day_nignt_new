import 'dart:convert';
import 'package:get/get.dart';
import '../core/auth/account_gate.dart';
import '../core/local_storage/local_storage.dart';
import '../core/resources/app_const/app_const.dart';
import '../modules/club_owner_side/activity/views/owner_event_ops_view.dart';
import '../modules/notification/views/notification_view.dart';
import '../modules/user_side/booking/controllers/booking_controller.dart';
import '../modules/user_side/booking/views/booking_details.dart';
import '../modules/user_side/club_details_view/views/club_details_view.dart';
import '../modules/user_side/home/model/club_model.dart';

class NotificationRouter {
  static bool _ready = false;
  static Map<String, dynamic>? _pending;

  static const _bookingTypes = {
    'BOOKING_CONFIRMED',
    'CLUB_BOOKING_CONFIRMED',
    'PAYMENT_FAILED',
    'TICKET_AVAILABLE',
    'NEW_CLUB_BOOKING',
    'NEW_TICKET_SALE',
    'REFUND_PROCESSED',
    'SELLER_TRANSFER_SUCCESS',
    'SELLER_TRANSFER_FAILED',
  };

  static void onDashboardReady() {
    _ready = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) open(pending);
  }

  static void onLoggedOut() {
    _ready = false;
    _pending = null;
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> source) {
    final result = Map<String, dynamic>.from(source);
    for (final key in ['metaData', 'metadata', 'data']) {
      dynamic nested = source[key];
      if (nested is String) {
        try {
          nested = jsonDecode(nested);
        } catch (_) {
          continue;
        }
      }
      if (nested is Map) result.addAll(Map<String, dynamic>.from(nested));
    }
    return result;
  }

  /// Unknown/incomplete targets open the inbox rather than inventing an ID/type.
  static bool open(Map<String, dynamic> source, {bool fallbackToInbox = true}) {
    if (!_ready || !AccountGate.isSignedIn || Get.key.currentState == null) {
      if (fallbackToInbox) _pending = Map<String, dynamic>.from(source);
      return false;
    }
    final data = normalize(source);
    final type =
        '${data['notificationType'] ?? data['type'] ?? ''}'.trim().toUpperCase();
    final clubId = '${data['clubId'] ?? ''}'.trim();
    final eventId = '${data['eventId'] ?? ''}'.trim();
    final orderId = '${data['orderId'] ?? ''}'.trim();
    final bookingId = '${data['bookingId'] ?? data['booking_id'] ?? ''}'.trim();
    final serviceType = '${data['serviceType'] ?? ''}'.trim().toUpperCase();
    final targetId = bookingId.isNotEmpty ? bookingId : orderId;

    if (type == 'HOST_INQUIRY') {
      final role =
          LocalStorage.getData(key: AppConst.role)?.toString().trim();
      final isOwner = role == 'CLUB_OWNER';
      if (isOwner && eventId.isNotEmpty) {
        Get.to(
          () => OwnerHostsView(
            eventId: eventId,
            initialTab: 1,
          ),
        );
        return true;
      }
      if (eventId.isNotEmpty) {
        Get.to(
          () => ClubDetailsView(
            clubModel: ClubModel(
              id: eventId,
              image: '',
              title: '',
              location: '',
              rating: '',
              price: '',
              type: 'Event',
            ),
          ),
        );
        return true;
      }
    }

    if ((type == 'GUEST_LIST_CONFIRMED' || type == 'GUEST_LIST_REJECTED') &&
        eventId.isNotEmpty) {
      Get.to(
        () => ClubDetailsView(
          clubModel: ClubModel(
            id: eventId,
            image: '',
            title: '',
            location: '',
            rating: '',
            price: '',
            type: 'Event',
          ),
        ),
      );
      return true;
    }

    if (type == 'CLUB_SEAT_AVAILABLE' && clubId.isNotEmpty) {
      Get.to(
        () => ClubDetailsView(
          clubModel: ClubModel(
            id: clubId,
            image: '',
            title: '',
            location: '',
            rating: '',
            price: '',
            type: 'Club',
          ),
        ),
      );
      return true;
    }

    if (_bookingTypes.contains(type) &&
        targetId.isNotEmpty &&
        (serviceType == 'EVENT' || serviceType == 'CLUB')) {
      Get.to(
        () => BookingDetailsView(
          booking: BookingModel(
            club: ClubModel(
              id: targetId,
              image: '',
              title: '',
              location: '',
              rating: '',
              price: '',
              type: serviceType,
            ),
            date: '',
            time: '',
            tickets: '',
            venue: '',
            price: '',
            total: '',
            status: type == 'PAYMENT_FAILED'
                ? BookingStatus.canceled
                : BookingStatus.upcoming,
            orderId: orderId,
            serviceType: serviceType,
          ),
        ),
      );
      return true;
    }

    if (fallbackToInbox) Get.to(() => const NotificationView());
    return false;
  }
}
