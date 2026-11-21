import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/utils/resource_const.dart';
import '../../explore/widget/club_event_card.dart';
import '../../explore/widget/explore_shimmer.dart';
import '../controllers/booking_controller.dart';
import 'booking_details.dart';

class MyBookingsView extends StatefulWidget {
  const MyBookingsView({super.key});

  @override
  State<MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<MyBookingsView> {
  late final BookingController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<BookingController>()
        ? Get.find<BookingController>()
        : Get.put(BookingController());
    controller.fetchBookings(refresh: true);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(
        title: "My Bookings",
        centerTitle: true,
        leading: SizedBox(),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Custom Tab Bar
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTab("Upcoming", 0, controller),
                _buildTab("Completed", 1, controller),
                // _buildTab("Canceled", 2, controller),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          Expanded(
            child: Obx(() {
              final tab = controller.currentTab;
              final bookings = tab.items;
              final loading = tab.isLoading.value && bookings.isEmpty;
              final loadingMore = tab.isLoadingMore.value;

              if (loading) {
                return const ExploreListShimmer(
                  showFavorite: false,
                  compact: true,
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 130),
                  separatorHeight: 20,
                );
              }

              if (bookings.isEmpty) {
                final isCompleted = controller.selectedTab.value == 1;
                return RefreshIndicator(
                  color: const Color(0xFFE1B144),
                  backgroundColor: Colors.black,
                  onRefresh: () => controller.fetchBookings(refresh: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
                    children: [
                      CompactEmptyState.stacked(
                        icon: isCompleted
                            ? Icons.history_rounded
                            : Icons.confirmation_number_outlined,
                        title: isCompleted
                            ? 'No completed bookings'
                            : 'No upcoming bookings',
                        message: isCompleted
                            ? 'Past reservations will appear here.'
                            : 'Your reservations will appear here.',
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: const Color(0xFFE1B144),
                backgroundColor: Colors.black,
                onRefresh: () => controller.fetchBookings(refresh: true),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                      controller.loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
                    itemCount: bookings.length + (loadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      if (index >= bookings.length) {
                        return const ExploreEventCardShimmer(
                          showFavorite: false,
                        );
                      }
                      final booking = bookings[index];
                      return GestureDetector(
                        onTap: () => Get.to(
                          () => BookingDetailsView(booking: booking),
                        ),
                        child: ClubEventCard(
                          club: booking.club,
                          isFavoriteBadgeShow: false,
                          ratingAsBadge: true,
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, BookingController controller) {
    bool isSel = controller.selectedTab.value == index;
    return GestureDetector(
      onTap: () => controller.selectTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSel ? Colors.orange : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: CustomText(
          text: label,
          color: isSel ? Colors.white : Colors.grey,
          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
