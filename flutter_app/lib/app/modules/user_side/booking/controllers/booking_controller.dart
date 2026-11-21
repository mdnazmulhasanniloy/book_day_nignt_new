import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/auth/account_gate.dart';
import '../../../../core/explore/model/explore_item_mapper.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../home/controllers/club_controller.dart' show ClubModel;
import '../repository/booking_repository.dart';

enum BookingStatus { upcoming, completed, canceled }

class BookingModel {
  final ClubModel club;
  final String date, time, tickets, venue, price, total;
  final BookingStatus status;
  final String orderId;
  final String serviceType;

  BookingModel({
    required this.club,
    required this.date,
    required this.time,
    required this.tickets,
    required this.venue,
    required this.price,
    required this.total,
    required this.status,
    this.orderId = '',
    this.serviceType = '',
  });
}

class BookingTabData {
  final items = <BookingModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  int page = 0;
  bool hasMore = true;
  bool busy = false;
}

class BookingController extends GetxController {
  BookingController({BookingRepository? repository})
      : _repository = repository ?? BookingRepository();

  final BookingRepository _repository;
  static const int pageLimit = 10;

  var selectedTab = 0.obs;

  final upcoming = BookingTabData();
  final completed = BookingTabData();
  final canceled = BookingTabData();

  BookingStatus get currentStatus {
    if (selectedTab.value == 1) return BookingStatus.completed;
    if (selectedTab.value == 2) return BookingStatus.canceled;
    return BookingStatus.upcoming;
  }

  BookingTabData tabData(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return completed;
      case BookingStatus.canceled:
        return canceled;
      case BookingStatus.upcoming:
        return upcoming;
    }
  }

  BookingTabData get currentTab => tabData(currentStatus);

  void selectTab(int index) {
    if (selectedTab.value == index) return;
    selectedTab.value = index;
    final tab = currentTab;
    if (tab.items.isEmpty && tab.hasMore) {
      fetchBookings(refresh: true);
    }
  }

  Future<void> fetchBookings({bool refresh = false}) async {
    if (!AccountGate.isSignedIn) return;
    final status = currentStatus;
    final tab = tabData(status);
    if (refresh) {
      tab.page = 0;
      tab.hasMore = true;
    }
    if (tab.busy) return;
    if (!tab.hasMore && !refresh) return;

    final nextPage = tab.page + 1;
    tab.busy = true;
    if (refresh || tab.items.isEmpty) {
      tab.isLoading.value = true;
    } else {
      tab.isLoadingMore.value = true;
    }

    try {
      final response = await _repository.fetchBookings(
        tab: _apiTab(status),
        page: nextPage,
        limit: pageLimit,
      );
      final mapped = response.data
          .map(
            (item) => _mapBooking(
              item.toClubModel(),
              status,
              item.type,
              item.orderId,
            ),
          )
          .toList(growable: false);
      if (refresh) tab.items.clear();
      tab.items.addAll(mapped);
      tab.page = nextPage;
      tab.hasMore = nextPage < response.meta.totalPages;
    } catch (error) {
      debugPrint('Bookings fetch error: $error');
      if (refresh || tab.items.isEmpty) {
        CustomSnackBar.error(message: 'Failed to load bookings');
      }
    } finally {
      tab.busy = false;
      tab.isLoading.value = false;
      tab.isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() => fetchBookings(refresh: false);

  String _apiTab(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return 'COMPLETED';
      case BookingStatus.canceled:
        return 'CANCELED';
      case BookingStatus.upcoming:
        return 'UPCOMING';
    }
  }

  BookingModel _mapBooking(
    ClubModel club,
    BookingStatus status,
    String serviceType,
    String orderId,
  ) {
    final place = club.location.trim().isEmpty ? '--' : club.location.trim();
    final amount = club.price.trim().isEmpty ? '--' : club.price.trim();
    final type = serviceType.trim().toUpperCase();
    return BookingModel(
      club: club,
      date: '--',
      time: '--',
      tickets: '--',
      venue: place,
      price: amount,
      total: amount,
      status: status,
      orderId: orderId.trim(),
      serviceType: type.contains('EVENT') ? 'EVENT' : 'CLUB',
    );
  }
}
