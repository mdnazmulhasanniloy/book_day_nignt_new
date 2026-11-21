import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/utils/custom_snack_bar.dart';
import '../../owner_home/repository/owner_stats_repository.dart';

class MonthEarningData {
  const MonthEarningData({required this.month, required this.amount});

  final String month;
  final double amount;
}

class OwnerEarningController extends GetxController {
  OwnerEarningController({OwnerStatsRepository? repository})
    : _repository = repository ?? OwnerStatsRepository();

  final OwnerStatsRepository _repository;

  final isLoading = true.obs;
  final todayRevenue = '€0'.obs;
  final last7DaysRevenue = '€0'.obs;
  final clubBookings = '0'.obs;
  final ticketsSold = '0'.obs;

  final selectedYear = '${DateTime.now().year}'.obs;
  final years = <String>[].obs;
  final monthlyEarnings = <MonthEarningData>[].obs;
  final recentPayments = <OwnerPaymentItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<MonthEarningData> get currentYearEarnings => monthlyEarnings;

  int get peakMonthIndex {
    final list = currentYearEarnings;
    if (list.isEmpty) return 0;
    var maxIndex = 0;
    var maxAmount = list.first.amount;
    for (var i = 1; i < list.length; i++) {
      if (list[i].amount > maxAmount) {
        maxAmount = list[i].amount;
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  Future<void> load({int? year}) async {
    final requested = year ?? int.tryParse(selectedYear.value) ?? DateTime.now().year;
    isLoading.value = true;
    try {
      final earnings = await _repository.fetchEarnings(year: requested);
      final payments = await _repository.fetchPayments(page: 1, limit: 4);
      todayRevenue.value = formatOwnerEuro(earnings.todayRevenue);
      last7DaysRevenue.value = formatOwnerEuro(earnings.last7DaysRevenue);
      clubBookings.value = '${earnings.todayTotalClubBookings}';
      ticketsSold.value = '${earnings.todayTotalEventTicketsSold}';
      final available = earnings.availableYears.isEmpty
          ? [earnings.selectedYear > 0 ? earnings.selectedYear : requested]
          : earnings.availableYears;
      years.assignAll(available.map((item) => '$item'));
      selectedYear.value = '${earnings.selectedYear > 0 ? earnings.selectedYear : requested}';
      monthlyEarnings.assignAll(
        earnings.months.map(
          (item) => MonthEarningData(month: item.label, amount: item.amount),
        ),
      );
      recentPayments.assignAll(payments.payments);
    } catch (error) {
      debugPrint('Owner earnings error: $error');
      CustomSnackBar.error(message: 'Failed to load earnings');
    } finally {
      isLoading.value = false;
    }
  }

  void changeYear(String year) {
    if (selectedYear.value == year) return;
    selectedYear.value = year;
    load(year: int.tryParse(year));
  }
}
