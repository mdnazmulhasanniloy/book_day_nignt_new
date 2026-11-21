import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../home/controllers/club_controller.dart';
import '../controllers/buy_ticker_controller.dart';
import '../views/view_ticket/phone_contacts_view.dart';
import '../views/view_ticket/ticket_booking_details.dart';

class GetYourTicketSheet extends StatelessWidget {
  final ClubModel clubModel;
  final DateTime? eventStartAt;
  final DateTime? eventEndAt;

  const GetYourTicketSheet({
    super.key,
    required this.clubModel,
    this.eventStartAt,
    this.eventEndAt,
  });

  void _rememberEvent() {
    final ticker = Get.isRegistered<BuyTickerController>()
        ? Get.find<BuyTickerController>()
        : Get.put(BuyTickerController());
    ticker.setEventSchedule(eventStartAt, eventEndAt);
  }

  @override
  Widget build(BuildContext context) {
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),

            const CustomText(
              text: "Get Your Ticket",
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            CustomText(
              text: "How would you like to join ${clubModel.title}?",
              fontSize: 13,
              color: Colors.grey,
            ),
            const SizedBox(height: 32),

            // Single Ticket
            _buildOptionCard(
              title: "Single Ticket",
              subtitle: "Just for yourself quick and easy",
              icon: Icons.person_outline,
              primaryYellow: primaryYellow,
              onTap: () {
                _rememberEvent();
                final ticker = Get.find<BuyTickerController>();
                ticker.prepareEventGuests(const []);
                Get.back();
                Get.to(() => TicketBookingDetailsView(
                      clubModel: clubModel,
                      isClub: false,
                    ));
              },
            ),
            const SizedBox(height: 16),

            // Invite Friends
            _buildOptionCard(
              title: "Invite Friends",
              subtitle: "Invite from phone contacts",
              icon: Icons.people_outline,
              primaryYellow: primaryYellow,
              isGoldenBorder: true,
              onTap: () {
                _rememberEvent();
                Get.back();
                Get.to(() => PhoneContactsView(clubModel: clubModel));
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryYellow,
    bool isGoldenBorder = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGoldenBorder ? primaryYellow : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGoldenBorder ? const Color(0xFF261D0A) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isGoldenBorder ? primaryYellow : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: title,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  CustomText(
                    text: subtitle,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isGoldenBorder ? primaryYellow : Colors.white54,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
