import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../controllers/owner_activity_controller.dart';
import '../model/promo_api_model.dart';
import '../widgets/activity_card_widget.dart';
import '../widgets/choose_create_type_sheet.dart';
import '../widgets/promo_code_card.dart';
import 'add_promo_view.dart';
import 'edit_club_view.dart';
import 'edit_event_view.dart';
import 'owner_club_details_view.dart';
import 'owner_event_details_view.dart';
import 'owner_event_ops_view.dart';

class OwnerActivityView extends StatelessWidget {
  const OwnerActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OwnerActivityController());
    const Color primaryYellow = Color(0xFFDCA73A);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Header (Title + Add Button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Get.to(() => const OwnerQuotesView()),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.request_quote_outlined,
                        color: Color(0xFFDCA73A),
                      ),
                    ),
                  ),
                  const CustomText(
                    text: "All Activity",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  GestureDetector(
                    onTap: () {
                      controller.selectedCreateType.value =
                          controller.isPromoTab ? 'Promo' : 'Club';
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => const ChooseCreateTypeSheet(),
                      );
                    },
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Main Tabs (Club | Event Toggle Pills)
            Obx(
              () => Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: List.generate(controller.mainTabs.length, (index) {
                    bool isSelected = controller.selectedMainTab.value == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => controller.changeMainTab(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF262626)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: CustomText(
                            text: controller.mainTabs[index],
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Events only: Upcoming | Completed. Clubs have no status tabs.
            Obx(() {
              if (controller.selectedMainTab.value != 1) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF262626), width: 1),
                      ),
                    ),
                    child: Row(
                      children: List.generate(
                        controller.eventStatusFilters.length,
                        (index) {
                          final isSelected =
                              controller.selectedStatusFilter.value == index;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => controller.changeStatusFilter(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isSelected
                                          ? primaryYellow
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: CustomText(
                                  text: controller.eventStatusFilters[index],
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),

            // Main Content Area (List or Empty View)
            Expanded(
              child: Obx(() {
                final isPromo = controller.isPromoTab;
                final list = isPromo
                    ? const <ActivityItemModel>[]
                    : controller.filteredList;
                final promoList = controller.promoList;
                final visibleEmpty =
                    isPromo ? promoList.isEmpty : list.isEmpty;

                if (controller.isLoading.value && visibleEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryYellow),
                  );
                }

                if (controller.errorMessage.value.isNotEmpty &&
                    visibleEmpty) {
                  return _buildErrorState(
                    controller.errorMessage.value,
                    controller.refreshCurrentType,
                    primaryYellow,
                  );
                }

                if (visibleEmpty && controller.hasMoreForCurrentType) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => controller.loadMoreActivities(),
                  );
                  return const Center(
                    child: CircularProgressIndicator(color: primaryYellow),
                  );
                }

                if (visibleEmpty) {
                  final isCompletedTab =
                      controller.selectedMainTab.value == 1 &&
                      controller.selectedStatusFilter.value == 1;
                  return RefreshIndicator(
                    color: primaryYellow,
                    backgroundColor: const Color(0xFF161616),
                    onRefresh: controller.refreshCurrentType,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.55,
                          child: _buildEmptyState(
                            context,
                            primaryYellow,
                            offerCreate: !isCompletedTab,
                            isPromo: isPromo,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (isPromo) {
                  return RefreshIndicator(
                    color: primaryYellow,
                    backgroundColor: const Color(0xFF161616),
                    onRefresh: controller.refreshCurrentType,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.extentAfter < 280) {
                          controller.loadMoreActivities();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                        itemCount:
                            promoList.length +
                            (controller.isLoadingMore.value ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == promoList.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryYellow,
                                  ),
                                ),
                              ),
                            );
                          }
                          final promo = promoList[index];
                          return PromoCodeCard(
                            promo: promo,
                            onEdit: () => _editPromo(controller, promo),
                            onDelete: () => _confirmDeletePromo(
                              context,
                              controller,
                              promo,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: primaryYellow,
                  backgroundColor: const Color(0xFF161616),
                  onRefresh: controller.refreshCurrentType,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.extentAfter < 280) {
                        controller.loadMoreActivities();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                      itemCount:
                          list.length +
                          (controller.isLoadingMore.value ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == list.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryYellow,
                                ),
                              ),
                            ),
                          );
                        }
                        final item = list[index];
                        if (index == list.length - 1 &&
                            controller.hasMoreForCurrentType) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => controller.loadMoreActivities(),
                          );
                        }
                        final isEvent = item.type.toUpperCase() == 'EVENT';
                        final canEdit =
                            !isEvent ||
                            controller.selectedStatusFilter.value == 0;
                        return ActivityCardWidget(
                          item: item,
                          isEditLoading:
                              controller.editingEventId.value == item.id,
                          onEdit: canEdit
                              ? () async {
                                  final full = await controller
                                      .prepareEventEditor(item);
                                  if (full == null) return;
                                  await Get.to(
                                    () => isEvent
                                        ? EditEventView(item: full)
                                        : EditClubView(item: full),
                                  );
                                }
                              : null,
                          onTap: () => item.type.toUpperCase() == 'EVENT'
                              ? Get.to(() => OwnerEventDetailsView(item: item))
                              : Get.to(() => OwnerClubDetailsView(item: item)),
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String message,
    Future<void> Function() onRetry,
    Color primaryYellow,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: Colors.white54,
              size: 52,
            ),
            const SizedBox(height: 16),
            const CustomText(
              text: 'Could not load activities',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            CustomText(
              text: message,
              fontSize: 12,
              color: Colors.grey,
              textAlign: TextAlign.center,
              maxLine: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              height: 46,
              child: CustomButton(
                title: 'Try Again',
                isGradient: false,
                buttonColor: primaryYellow,
                titleColor: Colors.black,
                borderRadius: 12,
                paddingVertical: 0,
                onTap: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color primaryYellow, {
    required bool offerCreate,
    bool isPromo = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: CompactEmptyState.stacked(
          icon: isPromo
              ? Icons.local_offer_outlined
              : offerCreate
              ? Icons.nightlife_outlined
              : Icons.event_busy_outlined,
          title: isPromo
              ? 'No promo codes'
              : offerCreate
              ? 'No clubs or events'
              : 'No completed events',
          message: isPromo
              ? 'Create a code for guests to use at checkout.'
              : offerCreate
              ? 'Create a club or event to get started.'
              : 'Finished events will appear here.',
          action: offerCreate
              ? CustomButton(
                  title: '+ Create New',
                  isGradient: false,
                  buttonColor: Colors.transparent,
                  border: Border.all(color: primaryYellow, width: 1),
                  titleColor: primaryYellow,
                  borderRadius: 12,
                  paddingVertical: 12,
                  fontSize: 14,
                  onTap: () {
                    Get.find<OwnerActivityController>()
                            .selectedCreateType
                            .value =
                        isPromo ? 'Promo' : 'Club';
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => const ChooseCreateTypeSheet(),
                    );
                  },
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _editPromo(
    OwnerActivityController controller,
    PromoDataModel promo,
  ) async {
    final updated = await Get.to(() => AddPromoView(existing: promo));
    if (updated is PromoDataModel) {
      controller.rememberUpdatedPromo(updated);
    }
  }

  Future<void> _confirmDeletePromo(
    BuildContext context,
    OwnerActivityController controller,
    PromoDataModel promo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const CustomText(
          text: 'Delete promo?',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: CustomText(
          text: '${promo.code.toUpperCase()} will be removed. This cannot be undone.',
          color: Colors.white70,
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFE57373),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deletePromo(promo);
  }
}
