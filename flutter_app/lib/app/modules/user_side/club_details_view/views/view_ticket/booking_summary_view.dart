import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../../home/controllers/club_controller.dart';
import '../../controllers/buy_ticker_controller.dart';
import '../../controllers/phone_contacts_controller.dart';
import 'ticket_booking_details.dart';

class BookingSummaryView extends StatelessWidget {
  final ClubModel clubModel;
  final bool isSingleTicket;

  const BookingSummaryView({
    super.key,
    required this.clubModel,
    this.isSingleTicket = false,
  });

  @override
  Widget build(BuildContext context) {
    // If it's a single ticket, we might not have a PhoneContactsController with data
    final phoneController = Get.isRegistered<PhoneContactsController>()
        ? Get.find<PhoneContactsController>()
        : null;

    final tickerController = Get.isRegistered<BuyTickerController>()
        ? Get.find<BuyTickerController>()
        : Get.put(BuyTickerController());

    const Color bgColor = Color(0xFF0D0D0D);
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);
    const Color primaryPink = Color(0xFFB13271);
    const Color primaryBlue = Color(0xFF2E65B5);
    const Color otherPurple = Color(0xFF9B6BE0);

    final List<ContactModel> guests = isSingleTicket
        ? <ContactModel>[]
        : (phoneController?.selectedContacts.toList() ?? <ContactModel>[]);
    final int ticketCount = guests.length + 1;

    int femaleCount = guests.where((g) => g.gender == "F").length;
    int maleCount = guests.where((g) => g.gender == "M").length;
    int otherCount = guests.where((g) => g.gender == "O").length;

    Color genderColor(String gender) => switch (gender) {
      "F" => primaryPink,
      "O" => otherPurple,
      _ => primaryBlue,
    };
    String genderLabel(String gender) => switch (gender) {
      "F" => "♀ Female",
      "O" => "Other",
      _ => "♂ Male",
    };

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const CustomAppBar(
        title: 'Booking Summary',
        backgroundColor: bgColor,
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: CustomButton(
                title: 'Get A Ticket',
                buttonColor: primaryYellow,
                isGradient: false,
                borderRadius: 16,
                paddingVertical: 14,
                titleColor: Colors.black,
                onTap: () {
                  tickerController.prepareEventGuests(guests);
                  Get.to(() => TicketBookingDetailsView(
                        clubModel: clubModel,
                        isClub: false,
                      ));
                },
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
            // GUEST LIST CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomText(
                    text: "GUEST LIST",
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          height: 24,
                          width: 24,
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const CustomText(
                            text: '1',
                            fontSize: 12,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: CustomText(
                            text: 'You',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const CustomText(
                          text: 'Buyer',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(guests.length, (index) {
                    final guest = guests[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Container(
                            height: 24,
                            width: 24,
                            decoration: BoxDecoration(
                              color: genderColor(
                                guest.gender,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: CustomText(
                              text: "${index + 2}",
                              fontSize: 12,
                              color: genderColor(guest.gender),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (guest.displayName.trim().isNotEmpty)
                                  CustomText(
                                    text: guest.displayName,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    maxLine: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                CustomText(
                                  text: guest.phoneNumber,
                                  fontSize: 14,
                                  color: Colors.grey,
                                  maxLine: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          CustomText(
                            text: genderLabel(guest.gender),
                            fontSize: 12,
                            color: genderColor(guest.gender),
                          ),
                          const SizedBox(width: 12),
                          CustomText(
                            text: "${guest.age}y",
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Counts Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCountBox(femaleCount, "Female", primaryPink),
                      const SizedBox(width: 12),
                      _buildCountBox(maleCount, "Male", primaryBlue),
                      const SizedBox(width: 12),
                      if (otherCount > 0) ...[
                        _buildCountBox(otherCount, "Other", otherPurple),
                        const SizedBox(width: 12),
                      ],
                      _buildCountBox(ticketCount, "Total", primaryYellow),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const CustomText(
              text: "EVENT DATE",
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: primaryYellow,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomText(
                          text: tickerController.eventDateLabel,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          maxLine: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _timeChip(tickerController.eventStartClock, primaryYellow),
                      if (tickerController.eventEndClock.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.white38,
                            size: 16,
                          ),
                        ),
                        _timeChip(tickerController.eventEndClock, primaryYellow),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomText(
        text: label,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildCountBox(int count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            CustomText(
              text: "$count",
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            const SizedBox(height: 4),
            CustomText(
              text: label,
              fontSize: 12,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
