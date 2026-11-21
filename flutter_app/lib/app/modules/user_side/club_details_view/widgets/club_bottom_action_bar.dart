import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/auth/account_gate.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../controllers/buy_ticker_controller.dart';
import '../controllers/club_details_controller.dart';
import '../views/view_ticket/select_date_time_view.dart';
import 'event_ticket_tier_sheet.dart';

class ClubBottomActionBar extends StatelessWidget {
  final ClubDetailsController controller;
  final Color bgColor;
  final Color primaryColor;
  final bool? isFavorite;

  const ClubBottomActionBar({
    super.key,
    required this.controller,
    required this.bgColor,
    required this.primaryColor,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Obx(() {
              final favorited = controller.isFavorite.value;
              final isClub = controller.isClub;
              final pastEvent = controller.isPastEvent;
              final closed = controller.detail.value?.bookingsClosed == true;
              final blocked = !isClub && (pastEvent || closed);
              return Row(
                children: [
                  GestureDetector(
                    onTap: controller.toggleFavorite,
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        favorited ? Icons.favorite : Icons.favorite_border,
                        color: favorited ? Colors.red : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      title: isClub
                          ? 'Reserve Table'
                          : closed
                          ? 'Bookings closed'
                          : pastEvent
                          ? 'Event ended'
                          : 'Get A Ticket',
                      isGradient: false,
                      buttonColor: blocked
                          ? const Color(0xFF2A2A2A)
                          : primaryColor,
                      titleColor: blocked ? Colors.white54 : Colors.white,
                      paddingVertical: 14,
                      borderRadius: 16,
                      onTap: blocked
                          ? null
                          : () async {
                              if (!await AccountGate.ensure()) return;
                              if (!context.mounted) return;
                              if (isClub) {
                                final hours =
                                    controller.detail.value?.openingHours ??
                                    const [];
                                Get.put(BuyTickerController())
                                    .setClubOpeningHours(hours);
                                Get.to(
                                  () => SelectDateTimeView(
                                    clubModel: controller.clubModel,
                                    openingHours: hours,
                                  ),
                                );
                              } else {
                                await openEventTicketFlow(
                                  context: context,
                                  controller: controller,
                                );
                              }
                            },
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}