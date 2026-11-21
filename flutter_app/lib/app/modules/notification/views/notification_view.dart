import '../../../services/notification_router.dart';
import 'package:bookdianight_app/app/core/resources/app_colors/App_Colors.dart';
import 'package:bookdianight_app/app/core/resources/common_widget/custom_app_bar.dart';
import 'package:bookdianight_app/app/core/resources/common_widget/custom_button.dart';
import '../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../core/resources/common_widget/custom_text.dart';
import '../../../core/utils/resource_const.dart';
import '../controller/notification_controller.dart';
import '../model/notification_model.dart';
import '../widgets/notification_card.dart';

class NotificationView extends StatefulWidget {
  const NotificationView({super.key});
  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  late final NotificationController controller;
  String _selectedDayFilter = 'All';

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.fetch(refresh: true);
    });
  }

  Widget _buildFilterBar() {
    const filters = ['All', 'Today', 'Yesterday', 'Earlier'];
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedDayFilter == filter;
          return Center(
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedDayFilter = filter),
              selectedColor: const Color(0xFFE1B144),
              backgroundColor: const Color(0xFF1E1E1E),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFE1B144)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: CustomAppBar(
        title: 'Notifications',
        actions: [
          Obx(() {
            if (controller.unreadCount == 0) return const SizedBox.shrink();
            if (controller.isMarkingRead.value) {
              return const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE1B144),
                    ),
                  ),
                ),
              );
            }
            return TextButton(
              onPressed: controller.markAllAsRead,
              child: const CustomText(
                text: 'Mark as read',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE1B144),
              ),
            );
          }),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.notifications.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFE1B144),
                    strokeWidth: 2,
                  ),
                );
              }

              if (controller.notifications.isEmpty) {
                return RefreshIndicator(
                  color: const Color(0xFFE1B144),
                  backgroundColor: Colors.black,
                  onRefresh: () => controller.fetch(refresh: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                    children: const [
                      CompactEmptyState.stacked(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications yet',
                        message: 'Updates will appear here.',
                      ),
                    ],
                  ),
                );
              }

              final groups = <String, List<NotificationModel>>{};
              for (final item in controller.notifications) {
                groups.putIfAbsent(item.group, () => []).add(item);
              }

              final filteredGroups = <String, List<NotificationModel>>{};
              for (final entry in groups.entries) {
                if (_selectedDayFilter == 'All') {
                  filteredGroups[entry.key] = entry.value;
                } else if (_selectedDayFilter == 'Today' &&
                    entry.key == 'Today') {
                  filteredGroups[entry.key] = entry.value;
                } else if (_selectedDayFilter == 'Yesterday' &&
                    entry.key == 'Yesterday') {
                  filteredGroups[entry.key] = entry.value;
                } else if (_selectedDayFilter == 'Earlier' &&
                    entry.key != 'Today' &&
                    entry.key != 'Yesterday') {
                  filteredGroups[entry.key] = entry.value;
                }
              }

              if (filteredGroups.isEmpty) {
                return Center(
                  child: CompactEmptyState.stacked(
                    icon: Icons.filter_list_off_rounded,
                    title: 'No $_selectedDayFilter notifications',
                    message:
                        'Try switching to another day filter or "All".',
                  ),
                );
              }

              return RefreshIndicator(
                color: const Color(0xFFE1B144),
                backgroundColor: Colors.black,
                onRefresh: () => controller.fetch(refresh: true),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scroll) {
                    if (scroll.metrics.pixels >=
                        scroll.metrics.maxScrollExtent - 240) {
                      controller.loadMore();
                    }
                    return false;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      for (final entry in filteredGroups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: CustomText(
                            text: entry.key,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ...entry.value.map(
                          (item) => NotificationCard(
                            data: item,
                            onTap: () {
                              controller.markAsRead(item);
                              if (!NotificationRouter.open(
                                item.routingData,
                                fallbackToInbox: false,
                              )) {
                                _showNotificationDetail(item);
                              }
                            },
                          ),
                        ),
                      ],
                      if (controller.isLoadingMore.value)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFE1B144),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

void _showNotificationDetail(NotificationModel item) {
  Get.dialog<void>(
    Dialog(
      backgroundColor: const Color(0xFF121212),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: Get.back,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 22,
                ),
              ),
            ),
            const CustomText(
              text: 'Notification',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE1B144),
            ),
            const SizedBox(height: 8),
            CustomText(
              text: item.title,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            if (item.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              CustomText(
                text: item.subtitle,
                fontSize: 14,
                color: const Color(0xFFB8B8B8),
                height: 1.45,
              ),
            ],
            if (item.when.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1B144).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE1B144).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFFE1B144),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomText(
                        text: item.when,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE1B144),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            CustomButton(
              title: 'Close',
              buttonColor: const Color(0xFFE1B144),
              titleColor: Colors.black,
              isGradient: false,
              borderRadius: 14,
              paddingVertical: 14,
              onTap: Get.back,
            ),
          ],
        ),
      ),
    ),
  );
}
