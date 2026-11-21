import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/auth/account_gate.dart';
import '../../../core/network/api_expection.dart';
import '../../../core/utils/custom_snack_bar.dart';
import '../model/notification_model.dart';
import '../repository/notification_repository.dart';

class NotificationController extends GetxController
    with WidgetsBindingObserver {
  NotificationController({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;
  final notifications = <NotificationModel>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final isMarkingRead = false.obs;

  int _page = 0;
  bool _hasMore = true;
  bool _busy = false;

  final serverUnreadCount = 0.obs;
  int get unreadCount => serverUnreadCount.value;
  final _markingIds = <String>{};

  Future<void> refreshUnreadCount() async {
    if (!AccountGate.isSignedIn) {
      serverUnreadCount.value = 0;
      return;
    }
    try {
      final count = await _repository.fetchUnreadCount();
      if (!isClosed) serverUnreadCount.value = count;
    } catch (_) {
      /* Preserve the last known server count on transient failures. */
    }
  }

  String get badgeLabel {
    final count = unreadCount;
    if (count <= 0) return '';
    if (count > 9) return '9+';
    return '$count';
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    fetch(refresh: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshUnreadCount();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  Future<void> fetch({bool refresh = false}) async {
    if (!AccountGate.isSignedIn) {
      notifications.clear();
      serverUnreadCount.value = 0;
      isLoading.value = false;
      return;
    }
    if (refresh) await refreshUnreadCount();
    if (_busy) return;
    if (!refresh && !_hasMore) return;
    if (refresh) {
      _page = 0;
      _hasMore = true;
    }

    final nextPage = _page + 1;
    _busy = true;
    if (refresh || notifications.isEmpty) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final result = await _repository.fetchNotifications(page: nextPage);
      if (refresh) notifications.clear();

      final filtered = <NotificationModel>[];
      for (final item in result.items) {
        final title = item.title.toLowerCase();
        final subtitle = item.subtitle.toLowerCase();
        final isCustomerInquirySent = title.contains('inquiry sent') ||
            subtitle.contains('your inquiry for host') ||
            subtitle.contains('the host will contact you shortly');

        if (isCustomerInquirySent) {
          // Silently mark as read if unread so badge count doesn't stay out of sync
          if (!item.isRead && item.id.isNotEmpty) {
            _repository.markRead(item.id).catchError((_) {});
            if (serverUnreadCount.value > 0) {
              serverUnreadCount.value--;
            }
          }
          continue;
        }
        filtered.add(item);
      }

      notifications.addAll(filtered);
      _page = nextPage;
      _hasMore = nextPage < result.totalPages && result.items.isNotEmpty;
    } on ApiException catch (error) {
      if (refresh || notifications.isEmpty) {
        _hasMore = false;
        CustomSnackBar.error(message: error.message);
      }
    } catch (error) {
      if (refresh || notifications.isEmpty) {
        _hasMore = false;
        CustomSnackBar.error(message: 'Failed to load notifications');
      }
    } finally {
      _busy = false;
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() => fetch(refresh: false);

  Future<void> markAllAsRead() async {
    if (isMarkingRead.value || unreadCount == 0) return;
    isMarkingRead.value = true;
    try {
      await _repository.markAllRead();
      for (final item in notifications) {
        item.isRead = true;
      }
      notifications.refresh();
      await refreshUnreadCount();
    } on ApiException catch (error) {
      CustomSnackBar.error(message: error.message);
    } catch (_) {
      CustomSnackBar.error(message: 'Could not mark notifications as read');
    } finally {
      isMarkingRead.value = false;
    }
  }

  Future<void> markAsRead(NotificationModel item) async {
    if (item.isRead || !_markingIds.add(item.id)) return;
    try {
      await _repository.markRead(item.id);
      item.isRead = true;
      notifications.refresh();
      await refreshUnreadCount();
    } catch (_) {
      CustomSnackBar.error(message: 'Could not mark notification as read');
    } finally {
      _markingIds.remove(item.id);
    }
  }
}
