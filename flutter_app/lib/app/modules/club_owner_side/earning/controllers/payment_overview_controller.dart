import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/utils/custom_snack_bar.dart';
import '../../activity/repository/club_repository.dart';
import '../../activity/repository/event_repository.dart';
import '../../owner_home/repository/owner_stats_repository.dart';

class OwnerFilterOption {
  const OwnerFilterOption({required this.id, required this.name});

  final String id;
  final String name;
}

class PaymentOverviewController extends GetxController {
  PaymentOverviewController({
    OwnerStatsRepository? repository,
    ClubRepository? clubRepository,
    EventRepository? eventRepository,
  }) : _repository = repository ?? OwnerStatsRepository(),
       _clubs = clubRepository ?? ClubRepository(),
       _events = eventRepository ?? EventRepository();

  final OwnerStatsRepository _repository;
  final ClubRepository _clubs;
  final EventRepository _events;

  static const allLabel = 'All';

  /// 0 = Club, 1 = Event
  final selectedTabIndex = 0.obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = false.obs;
  final payments = <OwnerPaymentItem>[].obs;

  final clubOptions = <OwnerFilterOption>[
    const OwnerFilterOption(id: '', name: allLabel),
  ].obs;
  final eventOptions = <OwnerFilterOption>[
    const OwnerFilterOption(id: '', name: allLabel),
  ].obs;
  final selectedClub = allLabel.obs;
  final selectedEvent = allLabel.obs;

  int _page = 0;
  var _busy = false;
  var _request = 0;

  @override
  void onInit() {
    super.onInit();
    loadFilters();
    load(refresh: true);
  }

  List<String> get clubNames =>
      clubOptions.map((item) => item.name).toList(growable: false);

  List<String> get eventNames =>
      eventOptions.map((item) => item.name).toList(growable: false);

  Future<void> loadFilters() async {
    try {
      final clubs = await _clubs.getOwnClubs(page: 1, limit: 50);
      final events = await _events.getOwnEvents(page: 1, limit: 50);
      clubOptions.assignAll([
        const OwnerFilterOption(id: '', name: allLabel),
        ...clubs.data
            .where((club) => club.id.isNotEmpty && club.name.trim().isNotEmpty)
            .map((club) => OwnerFilterOption(id: club.id, name: club.name)),
      ]);
      eventOptions.assignAll([
        const OwnerFilterOption(id: '', name: allLabel),
        ...events.data
            .where(
              (event) =>
                  event.id.isNotEmpty && event.eventName.trim().isNotEmpty,
            )
            .map(
              (event) =>
                  OwnerFilterOption(id: event.id, name: event.eventName),
            ),
      ]);
    } catch (error) {
      debugPrint('Owner payment filters error: $error');
    }
  }

  void selectTab(int index) {
    if (selectedTabIndex.value == index) return;
    selectedTabIndex.value = index;
    load(refresh: true);
  }

  void selectClub(String name) {
    if (selectedClub.value == name) return;
    selectedClub.value = name;
    load(refresh: true);
  }

  void selectEvent(String name) {
    if (selectedEvent.value == name) return;
    selectedEvent.value = name;
    load(refresh: true);
  }

  Future<void> load({bool refresh = false}) async {
    if (_busy && !refresh) return;
    if (refresh) {
      _page = 0;
      hasMore.value = true;
    } else if (!hasMore.value) {
      return;
    }

    final request = ++_request;
    final nextPage = refresh ? 1 : _page + 1;
    _busy = true;
    if (refresh || payments.isEmpty) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final page = await _repository.fetchPayments(
        type: _type,
        clubId: _clubId,
        eventId: _eventId,
        page: nextPage,
      );
      if (request != _request) return;
      if (refresh) payments.clear();
      payments.addAll(page.payments);
      _page = nextPage;
      hasMore.value = page.hasMore;
    } catch (error) {
      debugPrint('Owner payments error: $error');
      if (request == _request && refresh) {
        CustomSnackBar.error(message: 'Failed to load payments');
        payments.clear();
        hasMore.value = false;
      }
    } finally {
      if (request == _request) {
        _busy = false;
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> loadMore() => load();

  String? get _type => selectedTabIndex.value == 1 ? 'EVENT' : 'CLUB';

  String? get _clubId {
    if (selectedTabIndex.value != 0 || selectedClub.value == allLabel) {
      return null;
    }
    for (final option in clubOptions) {
      if (option.name == selectedClub.value && option.id.isNotEmpty) {
        return option.id;
      }
    }
    return null;
  }

  String? get _eventId {
    if (selectedTabIndex.value != 1 || selectedEvent.value == allLabel) {
      return null;
    }
    for (final option in eventOptions) {
      if (option.name == selectedEvent.value && option.id.isNotEmpty) {
        return option.id;
      }
    }
    return null;
  }
}
