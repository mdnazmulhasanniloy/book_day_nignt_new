import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/explore/model/event_offer_model.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../home/model/club_model.dart';
import '../controllers/buy_ticker_controller.dart';
import '../controllers/club_details_controller.dart';
import 'get_your_ticket_sheet.dart';

class EventTicketTierSheet extends StatelessWidget {
  const EventTicketTierSheet({
    super.key,
    required this.clubModel,
    required this.tiers,
    this.eventStartAt,
    this.eventEndAt,
    this.preferredTierId,
  });

  final ClubModel clubModel;
  final List<EventTicketTierModel> tiers;
  final DateTime? eventStartAt;
  final DateTime? eventEndAt;
  final String? preferredTierId;

  static const _card = Color(0xFF161616);
  static const _gold = Color(0xFFDCA73A);

  @override
  Widget build(BuildContext context) {
    final ticker = Get.isRegistered<BuyTickerController>()
        ? Get.find<BuyTickerController>()
        : Get.put(BuyTickerController());
    ticker.setEventSchedule(eventStartAt, eventEndAt);
    final flat = [for (final tier in tiers) ...tier.flattened];
    final preferred = preferredTierId?.trim() ?? '';
    if (preferred.isNotEmpty) {
      final match = flat.where((tier) => tier.id == preferred && !tier.isSoldOut);
      if (match.isNotEmpty) ticker.selectTicketTier(match.first);
    }
    if (ticker.selectedTicketTier.value == null) {
      final firstOpen = flat.where((tier) => !tier.isSoldOut);
      if (firstOpen.isNotEmpty) ticker.selectTicketTier(firstOpen.first);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            const CustomText(
              text: 'Tickets',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final tier in tiers)
                    Obx(() {
                      return _TierBranch(
                        tier: tier,
                        selected: ticker.selectedTicketTier.value,
                        onSelect: ticker.selectTicketTier,
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final selected = ticker.selectedTicketTier.value;
              final canContinue = selected != null && !selected.isSoldOut;
              return CustomButton(
                title: 'Continue',
                buttonColor: _gold,
                isGradient: false,
                borderRadius: 16,
                paddingVertical: 14,
                onTap: canContinue
                    ? () {
                        Get.back();
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => GetYourTicketSheet(
                            clubModel: clubModel,
                            eventStartAt: eventStartAt,
                            eventEndAt: eventEndAt,
                          ),
                        );
                      }
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TierBranch extends StatelessWidget {
  const _TierBranch({
    required this.tier,
    required this.selected,
    required this.onSelect,
    this.depth = 0,
  });

  final EventTicketTierModel tier;
  final EventTicketTierModel? selected;
  final ValueChanged<EventTicketTierModel> onSelect;
  final int depth;

  bool get _isSelected {
    if (selected == null) return false;
    if (tier.id.isNotEmpty && selected!.id == tier.id) return true;
    return selected!.tierName == tier.tierName && selected!.price == tier.price;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0, bottom: 10),
      child: Column(
        children: [
          _TierTile(
            tier: tier,
            selected: _isSelected,
            onTap: tier.isSoldOut ? null : () => onSelect(tier),
          ),
          for (final child in tier.children)
            _TierBranch(
              tier: child,
              selected: selected,
              onSelect: onSelect,
              depth: depth + 1,
            ),
        ],
      ),
    );
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final EventTicketTierModel tier;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final soldOut = tier.isSoldOut;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? EventTicketTierSheet._gold : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: tier.tierName,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  if (tier.groupName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    CustomText(
                      text: tier.groupName,
                      fontSize: 12,
                      color: const Color(0xFFA0A0A0),
                    ),
                  ],
                  const SizedBox(height: 4),
                  CustomText(
                    text: '€${tier.price.toStringAsFixed(tier.price % 1 == 0 ? 0 : 2)}',
                    fontSize: 13,
                    color: const Color(0xFFA0A0A0),
                  ),
                ],
              ),
            ),
            if (soldOut)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: EventTicketTierSheet._gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const CustomText(
                  text: 'Sold out',
                  fontSize: 11,
                  color: EventTicketTierSheet._gold,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? EventTicketTierSheet._gold : Colors.white38,
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> openEventTicketFlow({
  required BuildContext context,
  required ClubDetailsController controller,
  String? preferredTierId,
}) async {
  final club = controller.clubModel;
  final detail = controller.detail.value;
  if (detail?.bookingsClosed == true) {
    CustomSnackBar.error(message: 'Bookings are closed for this event.');
    return;
  }
  final tiers = detail?.ticketTiers ?? const <EventTicketTierModel>[];
  if (tiers.isNotEmpty) {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EventTicketTierSheet(
        clubModel: club,
        tiers: tiers,
        eventStartAt: detail?.startAt,
        eventEndAt: detail?.endAt,
        preferredTierId: preferredTierId,
      ),
    );
    return;
  }
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => GetYourTicketSheet(
      clubModel: club,
      eventStartAt: detail?.startAt,
      eventEndAt: detail?.endAt,
    ),
  );
}
