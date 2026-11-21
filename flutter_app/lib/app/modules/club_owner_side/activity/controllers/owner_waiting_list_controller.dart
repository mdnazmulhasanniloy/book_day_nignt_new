import 'package:get/get.dart';

import '../../../../core/network/api_expection.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../model/owner_waiting_list_model.dart';
import '../repository/owner_waiting_list_repository.dart';

class OwnerWaitingListController extends GetxController {
  OwnerWaitingListController({
    required this.clubId,
    OwnerWaitingListRepository? repository,
  }) : _repository = repository ?? OwnerWaitingListRepository();

  final String clubId;
  final OwnerWaitingListRepository _repository;

  static const _pageSize = 20;

  final entries = <OwnerWaitingListEntry>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final errorMessage = ''.obs;
  final forbidden = false.obs;
  final notFound = false.obs;
  final notifyingIds = <String>[].obs;
  final removingIds = <String>[].obs;

  int _page = 0;
  int _totalPages = 1;
  bool _busy = false;

  bool get hasMore => _page < _totalPages;

  @override
  void onInit() {
    super.onInit();
    fetch(refresh: true);
  }

  Future<void> fetch({bool refresh = false}) async {
    if (_busy && !refresh) return;
    if (!refresh && !hasMore) return;
    _busy = true;
    if (refresh) {
      isLoading.value = true;
      errorMessage.value = '';
      forbidden.value = false;
      notFound.value = false;
      _page = 0;
      _totalPages = 1;
    } else {
      isLoadingMore.value = true;
    }
    try {
      final next = _page + 1;
      final page = await _repository.list(
        clubId: clubId,
        page: next,
        limit: _pageSize,
      );
      _page = page.page;
      _totalPages = page.totalPages < 1 ? 1 : page.totalPages;
      if (refresh) {
        entries.assignAll(page.data);
      } else {
        for (final row in page.data) {
          final index = entries.indexWhere((item) => item.id == row.id);
          if (index == -1) {
            entries.add(row);
          } else {
            entries[index] = row;
          }
        }
        entries.refresh();
      }
    } catch (error) {
      final code = error is ApiException ? error.statusCode : null;
      forbidden.value = code == 403;
      notFound.value = code == 404;
      errorMessage.value = clientErrorMessage(
        error,
        'Could not load waiting list',
      );
      if (!refresh && entries.isNotEmpty) {
        CustomSnackBar.error(message: errorMessage.value);
      }
    } finally {
      _busy = false;
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> notify(OwnerWaitingListEntry entry) async {
    if (entry.id.isEmpty || notifyingIds.contains(entry.id)) return;
    notifyingIds.add(entry.id);
    notifyingIds.refresh();
    try {
      final updated = await _repository.notify(entry.id);
      _replace(updated);
      CustomSnackBar.success(message: 'Guest notified');
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not notify this guest'),
      );
    } finally {
      notifyingIds.remove(entry.id);
      notifyingIds.refresh();
    }
  }

  Future<void> remove(OwnerWaitingListEntry entry) async {
    if (entry.id.isEmpty || removingIds.contains(entry.id)) return;
    removingIds.add(entry.id);
    removingIds.refresh();
    try {
      await _repository.remove(entry.id);
      entries.removeWhere((item) => item.id == entry.id);
      CustomSnackBar.success(message: 'Guest removed from the queue');
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not remove this guest'),
      );
    } finally {
      removingIds.remove(entry.id);
      removingIds.refresh();
    }
  }

  void _replace(OwnerWaitingListEntry updated) {
    final index = entries.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      entries.insert(0, updated);
      entries.refresh();
      return;
    }
    final current = entries[index];
    final keepUser =
        updated.user.id.isEmpty && current.user.id.isNotEmpty;
    entries[index] = updated.copyWith(
      user: keepUser ? current.user : updated.user,
      position: updated.position ?? current.position,
    );
    entries.refresh();
  }
}
