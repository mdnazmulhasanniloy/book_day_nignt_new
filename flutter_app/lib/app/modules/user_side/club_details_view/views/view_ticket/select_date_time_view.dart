import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../../core/explore/model/explore_api_model.dart';
import '../../../../../core/resources/common_widget/address_from_coordinates.dart';
import '../../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../../home/controllers/club_controller.dart';
import '../../controllers/buy_ticker_controller.dart';
import '../../controllers/club_details_controller.dart';
import 'club_interval_sheet.dart';
import 'select_package_view.dart';
import 'ticket_booking_details.dart';

class SelectDateTimeView extends StatelessWidget {
  final ClubModel? clubModel;
  final List<ExploreOpeningHourModel> openingHours;

  const SelectDateTimeView({
    super.key,
    this.clubModel,
    this.openingHours = const [],
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BuyTickerController());
    final hours = openingHours.isNotEmpty
        ? openingHours
        : (Get.isRegistered<ClubDetailsController>()
              ? (Get.find<ClubDetailsController>().detail.value?.openingHours ??
                    const <ExploreOpeningHourModel>[])
              : const <ExploreOpeningHourModel>[]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.setClubOpeningHours(hours);
    });
    const Color bgColor = Color(0xFF0D0D0D);
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);

    final ClubModel effectiveClubModel = clubModel ??
        ClubModel(
          title: 'XOYO London',
          type: 'event',
          image:
              'https://images.unsplash.com/photo-1540039155732-d688d52cb4b1',
          price: '€191.00',
          rating: '4.8',
          location: 'Shoreditch',
        );

    bool isClub = effectiveClubModel.type.toLowerCase() == 'club';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const CustomAppBar(
        title: 'Select Date & Time',
        backgroundColor: bgColor,
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20.0, vertical: 12.0),
              child: Obx(
                () => CustomButton(
                  title: isClub ? 'Check Availability' : 'Get A Ticket',
                  buttonColor: primaryYellow,
                  isGradient: false,
                  borderRadius: 16,
                  paddingVertical: 14,
                  isLoading: controller.isLoadingPackages.value,
                  onTap: () async {
                    if (!isClub) {
                      Get.to(() => TicketBookingDetailsView(
                            clubModel: effectiveClubModel,
                            isClub: false,
                          ));
                      return;
                    }
                    final loaded = await controller.loadClubPackages(
                      effectiveClubModel.id,
                    );
                    if (!loaded) return;
                    Get.to(() => SelectPackageView(
                          clubModel: effectiveClubModel,
                        ));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEventCard(effectiveClubModel, cardBgColor, primaryYellow),
            const SizedBox(height: 24),

            if (isClub) ...[
              const CustomText(
                text: 'Reservation time',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              const SizedBox(height: 4),
              Obx(() {
                final closed = controller.closedWeekdayNames;
                return CustomText(
                  text: closed.isEmpty
                      ? 'Pick a start, then an end.'
                      : 'Closed days (${closed.join(', ')}) can’t be booked.',
                  fontSize: 12,
                  color: Colors.white54,
                );
              }),
              const SizedBox(height: 12),
              _buildIntervalCard(
                context,
                controller,
                cardBgColor,
                primaryYellow,
                isStart: true,
              ),
              const SizedBox(height: 12),
              _buildIntervalCard(
                context,
                controller,
                cardBgColor,
                primaryYellow,
                isStart: false,
              ),
            ] else ...[
              _buildCalendarCard(cardBgColor, primaryYellow, controller),
              const SizedBox(height: 16),
              _buildEventFixedTimeSelector(cardBgColor),
            ],

            const SizedBox(height: 24),
            const CustomText(
              text: 'Guests',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            _buildGuestCounter(cardBgColor, primaryYellow, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
      ClubModel club, Color cardBgColor, Color primaryYellow) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CustomNetworkImage(
                imageUrl: club.image,
                height: 140,
                width: double.infinity,
                borderRadius: BorderRadius.circular(12),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CustomText(
                    text: club.type.toLowerCase() == 'club' ? 'Club' : 'Event',
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomText(
                  text: club.title,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  maxLine: 2,
                  overflow: TextOverflow.ellipsis,
                  height: 1.25,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.star, color: primaryYellow, size: 14),
              const SizedBox(width: 4),
              CustomText(
                text: club.rating,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: AddressFromCoordinates(
                  lat: club.latitude,
                  lng: club.longitude,
                  existingAddress: club.location,
                  color: Colors.grey,
                  fontSize: 14,
                  maxLine: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(
    Color cardBgColor,
    Color primaryYellow,
    BuyTickerController controller,
  ) {
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Obx(() {
      DateTime focused = controller.focusedDate.value;
      DateTime selected = controller.selectedDate.value;

      int daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;
      DateTime firstDayOfMonth = DateTime(focused.year, focused.month, 1);
      int startingWeekday = firstDayOfMonth.weekday; // 1 = Mon, ..., 7 = Sun
      int leadingEmptySlots = startingWeekday - 1;

      int daysInPrevMonth = DateTime(focused.year, focused.month, 0).day;
      int totalGridItems = leadingEmptySlots + daysInMonth;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Month Header Row with Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: controller.previousMonth,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.grey,
                      size: 16,
                    ),
                  ),
                ),
                CustomText(
                  text: '${DateFormat('MMMM yyyy').format(focused)} ⌄',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                GestureDetector(
                  onTap: controller.nextMonth,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Weekday Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: CustomText(
                          text: day,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Real Days Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalGridItems,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (index < leadingEmptySlots) {
                  int prevDay =
                      daysInPrevMonth - (leadingEmptySlots - 1 - index);
                  return Center(
                    child: CustomText(
                      text: '$prevDay',
                      color: Colors.white24,
                    ),
                  );
                }

                int dayNum = index - leadingEmptySlots + 1;
                DateTime currentDate =
                    DateTime(focused.year, focused.month, dayNum);

                bool isSelected = controller.isSameDay(currentDate, selected);
                bool isPast = controller.isPastDate(currentDate);

                return GestureDetector(
                  onTap: isPast
                      ? null
                      : () => controller.selectCalendarDate(currentDate),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? primaryYellow : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: CustomText(
                      text: '$dayNum',
                      color: isSelected
                          ? Colors.black
                          : (isPast ? Colors.white24 : Colors.white),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildIntervalCard(
    BuildContext context,
    BuyTickerController controller,
    Color cardBgColor,
    Color primaryYellow, {
    required bool isStart,
  }) {
    return Obx(() {
      final when = isStart ? controller.clubStart.value : controller.clubEnd.value;
      final showRequired = when == null && controller.intervalRequired.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: primaryYellow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                CustomText(
                  text: isStart ? 'Starts' : 'Ends',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _intervalRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: when == null ? 'Select date' : controller.dateLabel(when),
              valueColor: showRequired ? const Color(0xFFFF6B6B) : null,
              primaryYellow: primaryYellow,
              onTap: () => showClubIntervalSheet(
                context: context,
                controller: controller,
                isStart: isStart,
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 20),
            _intervalRow(
              icon: Icons.schedule,
              label: 'Time',
              value: when == null ? 'Select time' : controller.clockLabel(when),
              valueColor: showRequired ? const Color(0xFFFF6B6B) : null,
              primaryYellow: primaryYellow,
              onTap: () => showClubIntervalSheet(
                context: context,
                controller: controller,
                isStart: isStart,
                openOnTime: when != null,
              ),
            ),
            if (showRequired) ...[
              const SizedBox(height: 10),
              CustomText(
                text: isStart
                    ? 'Start date and time is required'
                    : 'End date and time is required',
                fontSize: 11,
                color: const Color(0xFFFF6B6B),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _intervalRow({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryYellow,
    required VoidCallback onTap,
    Color? valueColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, color: primaryYellow, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: label,
                  fontSize: 11,
                  color: Colors.white54,
                ),
                const SizedBox(height: 2),
                CustomText(
                  text: value,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ??
                      (value.startsWith('Select ')
                          ? Colors.white38
                          : Colors.white),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        ],
      ),
    );
  }

  Widget _buildEventFixedTimeSelector(Color cardBgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const CustomText(
            text: 'Time',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CustomText(
              text: '6 pm — 11 pm',
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestCounter(
    Color cardBgColor,
    Color primaryYellow,
    BuyTickerController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, color: primaryYellow),
              const SizedBox(width: 8),
              Obx(
                () => CustomText(
                  text: '${controller.guestCount.value} guests',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: controller.decrementGuest,
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Obx(
                () => CustomText(
                  text: '${controller.guestCount.value}',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: controller.incrementGuest,
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: primaryYellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
