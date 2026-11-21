import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/utils/custom_snack_bar.dart';
import '../../club_details_view/repository/club_review_repository.dart';
import '../model/booking_detail_model.dart';
import '../repository/booking_repository.dart';
import 'booking_controller.dart';

class BookingDetailsController extends GetxController {
  BookingDetailsController({
    required this.seed,
    BookingRepository? repository,
    ClubReviewRepository? reviewRepository,
  }) : _repository = repository ?? BookingRepository(),
       _reviewRepository = reviewRepository ?? ClubReviewRepository();

  final BookingModel seed;
  final BookingRepository _repository;
  final ClubReviewRepository _reviewRepository;

  final detail = Rxn<BookingDetailModel>();
  final isLoading = true.obs;
  final ticketBytes = Rxn<Uint8List>();
  final isTicketLoading = false.obs;
  final isSubmittingReview = false.obs;
  final reviewed = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  String get bookingId => seed.club.id.trim();

  /// Door QR must be the payment order UUID, never booking/event/club id.
  String get doorOrderId {
    final fromDetail = detail.value?.orderId.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    return seed.orderId.trim();
  }

  String get bookingType {
    final type = seed.serviceType.trim().isNotEmpty
        ? seed.serviceType
        : seed.club.type;
    if (type.toUpperCase().contains('EVENT')) return 'EVENT';
    return 'CLUB';
  }

  Future<void> load() async {
    if (bookingId.trim().isEmpty) {
      isLoading.value = false;
      CustomSnackBar.error(message: 'This booking could not be opened.');
      return;
    }
    isLoading.value = true;
    try {
      final result = await _repository.fetchBookingDetail(
        id: bookingId,
        type: bookingType,
      );
      detail.value = result;
    } catch (error) {
      debugPrint('Booking detail error: $error');
      final resolved = await _tryResolveBookingByOrderId(bookingId);
      if (resolved != null) {
        detail.value = resolved;
      } else {
        CustomSnackBar.error(message: 'Failed to load booking details');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<BookingDetailModel?> _tryResolveBookingByOrderId(String idToMatch) async {
    final target = (seed.orderId.isNotEmpty ? seed.orderId : idToMatch).trim();
    if (target.isEmpty) return null;
    try {
      for (final tab in ['UPCOMING', 'COMPLETED']) {
        final res = await _repository.fetchBookings(tab: tab, page: 1, limit: 20);
        for (final item in res.data) {
          if (item.orderId.trim() == target || item.id.trim() == target) {
            return await _repository.fetchBookingDetail(
              id: item.id.trim(),
              type: item.type.toUpperCase().contains('EVENT') ? 'EVENT' : 'CLUB',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Resolve booking by orderId error: $e');
    }
    return null;
  }

  Future<bool> submitReview({
    required int rating,
    required String review,
  }) async {
    final clubId = detail.value?.clubId.trim() ?? '';
    if (clubId.isEmpty) {
      CustomSnackBar.error(message: 'This club could not be reviewed.');
      return false;
    }
    if (isSubmittingReview.value) return false;
    isSubmittingReview.value = true;
    try {
      await _reviewRepository.createReview(
        clubId: clubId,
        rating: rating,
        review: review,
      );
      reviewed.value = true;
      CustomSnackBar.success(message: 'Review submitted');
      return true;
    } catch (error) {
      debugPrint('Create review error: $error');
      final message = error.toString().trim();
      CustomSnackBar.error(
        message: message.isEmpty ? 'Failed to submit review' : message,
      );
      return false;
    } finally {
      isSubmittingReview.value = false;
    }
  }

  Future<Uint8List?> downloadTicket() async {
    if (isTicketLoading.value) return null;
    final current = detail.value;
    if (current == null || !current.ticketReady) {
      CustomSnackBar.error(message: 'Ticket PDF is not ready yet');
      return null;
    }
    isTicketLoading.value = true;
    try {
      final candidates = <String>[
        if (current.id.trim().isNotEmpty) current.id.trim(),
        if (bookingId.trim().isNotEmpty) bookingId.trim(),
        if (current.orderId.trim().isNotEmpty) current.orderId.trim(),
      ].toSet().toList();

      Uint8List? bytes;
      Object? lastError;
      for (final id in candidates) {
        try {
          bytes = await _repository.fetchTicket(id);
          if (bytes.isNotEmpty) break;
        } catch (e) {
          lastError = e;
          debugPrint('fetchTicket candidate $id failed: $e');
        }
      }
      if (bytes == null || bytes.isEmpty) {
        if (lastError != null) throw lastError;
        throw StateError('Empty ticket data');
      }
      ticketBytes.value = bytes;
      return bytes;
    } catch (error) {
      debugPrint('Booking ticket download error: $error');
      CustomSnackBar.error(message: 'Could not download the ticket');
      return null;
    } finally {
      isTicketLoading.value = false;
    }
  }
}
