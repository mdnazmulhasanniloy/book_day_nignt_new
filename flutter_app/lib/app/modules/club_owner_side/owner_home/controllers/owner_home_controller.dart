import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/custom_snack_bar.dart';
import '../repository/owner_stats_repository.dart';

class OwnerOverviewStat {
  const OwnerOverviewStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

class OwnerHomeController extends GetxController {
  OwnerHomeController({OwnerStatsRepository? repository})
    : _repository = repository ?? OwnerStatsRepository();

  final OwnerStatsRepository _repository;

  final isLoading = true.obs;
  final overview = <OwnerOverviewStat>[].obs;
  final recentBookings = <OwnerRecentBooking>[].obs;
  final recentPayments = <OwnerPaymentItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _repository.fetchDashboard(),
        _repository.fetchPayments(page: 1, limit: 4),
      ]);
      final dashboard = results[0] as OwnerDashboardModel;
      final payments = results[1] as OwnerPaymentsPage;
      overview.assignAll([
        OwnerOverviewStat(
          icon: Icons.account_balance_wallet_outlined,
          value: formatOwnerEuro(dashboard.totalEarnings),
          label: 'Total Earnings',
        ),
        OwnerOverviewStat(
          icon: Icons.calendar_month_outlined,
          value: formatOwnerEuro(dashboard.thisMonthEarnings),
          label: 'This Month',
        ),
        OwnerOverviewStat(
          icon: Icons.chair_outlined,
          value: '${dashboard.totalClubBookings}',
          label: 'Club Bookings',
        ),
        OwnerOverviewStat(
          icon: Icons.confirmation_num_outlined,
          value: '${dashboard.totalEventTicketsSold}',
          label: 'Tickets Sold',
        ),
      ]);
      recentBookings.assignAll(dashboard.recentBookings);
      recentPayments.assignAll(payments.payments);
    } catch (error) {
      debugPrint('Owner dashboard error: $error');
      CustomSnackBar.error(message: 'Failed to load dashboard');
    } finally {
      isLoading.value = false;
    }
  }
}
