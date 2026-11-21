import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/resources/common_widget/address_from_coordinates.dart';
import '../../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../../dashboard/user_dashboard.dart';
import '../../../home/controllers/club_controller.dart';
import '../../controllers/buy_ticker_controller.dart';
import 'ticket_details_view.dart';

class TicketBookingDetailsView extends StatelessWidget {
  final ClubModel? clubModel;
  final bool isClub;

  const TicketBookingDetailsView({
    super.key,
    this.clubModel,
    this.isClub = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BuyTickerController>();
    const Color bgColor = Color(0xFF0D0D0D);
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);

    final ClubModel effectiveClub = clubModel ??
        ClubModel(
          title: isClub ? 'Sky Garden Rooftop' : 'XOYO London',
          type: isClub ? 'club' : 'event',
          image: isClub
              ? 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819'
              : 'https://images.unsplash.com/photo-1540039155732-d688d52cb4b1',
          price: isClub ? 'From €65' : '€191.00',
          rating: '4.8',
          location: isClub ? 'Farringdon, EC1' : 'Shoreditch',
        );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CustomAppBar(
        title: 'Booking Details',
        backgroundColor: bgColor,
        actions: isClub
            ? null
            : [
                TextButton(
                  onPressed: _focusPromo,
                  child: const CustomText(
                    text: 'I HAVE A CODE',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryYellow,
                  ),
                ),
              ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Obx(
                () {
                  final quote = _bookingQuote(
                    controller,
                    isClub,
                    effectiveClub.price,
                  );
                  return CustomButton(
                    title: quote.totalLabel.isEmpty
                        ? 'Pay & Confirm Booking'
                        : 'Pay & Confirm Booking • ${quote.totalLabel}',
                    buttonColor: primaryYellow,
                    isGradient: false,
                    borderRadius: 16,
                    paddingVertical: 14,
                    isLoading: controller.isPaying.value,
                    onTap: () async {
                      final paid = isClub
                          ? await controller.payForSelectedClub()
                          : await controller.payForEvent(effectiveClub.id);
                      if (!paid || !context.mounted) return;
                      _showPaymentSuccessDialog(
                        context,
                        effectiveClub,
                        primaryYellow,
                        cardBgColor,
                      );
                    },
                  );
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
            _buildEventCard(effectiveClub, cardBgColor, primaryYellow),
            const SizedBox(height: 24),

            // Booking Summary
            if (isClub)
              _buildSummaryCard(cardBgColor, 'Booking summary', {
                'Place': AddressFromCoordinates(
                  lat: effectiveClub.latitude,
                  lng: effectiveClub.longitude,
                  existingAddress: effectiveClub.location,
                  color: Colors.white,
                  fontSize: 14,
                  maxLine: 2,
                ),
                'Date': controller.clubDateSummary,
                'Time': controller.clubTimeSummary,
                'Package': controller.selectedPackage['title'] ?? 'VIP Table',
              })
            else
              Obx(
                () => _buildSummaryCard(cardBgColor, 'Booking summary', {
                  'Date': controller.eventDateLabel,
                  'Time': controller.eventTimeLabel,
                  if (controller.selectedTicketTier.value != null)
                    'Tier': controller.selectedTicketTier.value!.tierName,
                  'Ticket':
                      '${controller.guestCount.value} ticket${controller.guestCount.value == 1 ? '' : 's'}',
                }),
              ),

            if (!isClub) ...[
              const SizedBox(height: 24),
              _PromoCodeCard(
                key: _promoSectionKey,
                controller: controller,
                eventId: effectiveClub.id,
                fallbackPrice: effectiveClub.price,
              ),
            ],

            const SizedBox(height: 24),

            Obx(() {
              final quote = _bookingQuote(
                controller,
                isClub,
                effectiveClub.price,
              );
              return Column(
                children: [
                  _buildSummaryCard(
                    cardBgColor,
                    'Price breakdown',
                    quote.rows,
                    isPriceBreakdown: true,
                    totalAmountString: quote.totalLabel,
                    primaryYellow: primaryYellow,
                  ),
                  if (controller.serviceCharge.value > 0)
                    TextButton(
                      onPressed: () => _showServiceFeeDetails(context),
                      child: const CustomText(
                        text: 'Service fee details',
                        fontSize: 13,
                        color: primaryYellow,
                      ),
                    ),
                ],
              );
            }),
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

  Widget _buildSummaryCard(
    Color cardBgColor,
    String title,
    Map<String, Object> data, {
    bool isPriceBreakdown = false,
    String totalAmountString = '€576',
    Color? primaryYellow,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            text: title,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          ...data.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  CustomText(text: e.key, fontSize: 14, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: switch (e.value) {
                      final Widget widget => Align(
                          alignment: Alignment.centerRight,
                          child: widget,
                        ),
                      final value => CustomText(
                          text: '$value',
                          fontSize: 14,
                          color: Colors.white,
                          textAlign: TextAlign.right,
                          maxLine: 2,
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
          if (isPriceBreakdown) ...[
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const CustomText(
                  text: 'Total',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                CustomText(
                  text: totalAmountString,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryYellow ?? Colors.white,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPaymentSuccessDialog(
    BuildContext context,
    ClubModel club,
    Color primaryYellow,
    Color cardBgColor,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(24),
            ),
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
                const SizedBox(height: 32),
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 24),
                const CustomText(
                  text: 'Payment Successful!',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                CustomText(
                  text: isClub
                      ? 'You\'ve successfully reserved your club table, for detailed information you can check on my booking page.'
                      : 'You\'ve successfully booked the event ticket, for detailed information you can check on my booking page.',
                  fontSize: 14,
                  color: Colors.grey,
                  textAlign: TextAlign.center,
                  height: 1.5,
                ),
                const SizedBox(height: 32),
                CustomButton(
                  title: isClub ? 'View Reservation' : 'View Event Ticket',
                  buttonColor: primaryYellow,
                  isGradient: false,
                  borderRadius: 16,
                  onTap: () {
                    Get.back(); // close dialog
                    Get.to(() => TicketDetailsView(
                          clubModel: club,
                          isClub: isClub,
                        ));
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Get.offAll(() => const UserDashboard()),
                  child: const CustomText(
                    text: 'Back To Homepage',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

double _eventUnitPrice(String raw) {
  final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(raw);
  if (match == null) return 0;
  return double.tryParse(match.group(0)!) ?? 0;
}

class _BookingQuote {
  const _BookingQuote({required this.rows, required this.totalLabel});

  final Map<String, String> rows;
  final String totalLabel;
}

_BookingQuote _bookingQuote(
  BuyTickerController controller,
  bool isClub,
  String eventPrice,
) {
  final fee = controller.serviceCharge.value;
  final feeLabel = fee > 0 ? controller.formatEuro(fee) : '';

  if (isClub) {
    final package = controller.selectedPackage;
    final title = package['title']?.toString() ?? 'VIP Table';
    final priceLabel = package['price']?.toString() ?? '';
    final price = (package['numericPrice'] as num?)?.toDouble() ??
        _eventUnitPrice(priceLabel);
    final total = price + fee;
    return _BookingQuote(
      rows: {
        'Package': title,
        'Price': price > 0 ? controller.formatEuro(price) : priceLabel,
        if (feeLabel.isNotEmpty) 'Service charge': feeLabel,
      },
      totalLabel: price > 0 || fee > 0 ? controller.formatEuro(total) : '',
    );
  }

  final unit = controller.eventUnitPrice(eventPrice);
  final tickets = controller.guestCount.value;
  final subtotal = unit * tickets;
  final promo = controller.appliedPromo.value;
  final discounted = promo != null ? promo.finalAmount : subtotal;
  final total = discounted + fee;
  return _BookingQuote(
    rows: {
      if (controller.selectedTicketTier.value != null)
        'Tier': controller.selectedTicketTier.value!.tierName,
      'Price': unit > 0 ? controller.formatEuro(unit) : '--',
      'Tickets': '$tickets',
      'Subtotal': controller.formatEuro(subtotal),
      if (promo != null)
        'Promo (${promo.code})': '-${controller.formatEuro(promo.discountAmount)}',
      if (feeLabel.isNotEmpty) 'Service charge': feeLabel,
    },
    totalLabel: discounted > 0 || fee > 0 ? controller.formatEuro(total) : '',
  );
}

final _promoSectionKey = GlobalKey();

void _focusPromo() {
  final context = _promoSectionKey.currentContext;
  if (context == null) return;
  Scrollable.ensureVisible(
    context,
    duration: const Duration(milliseconds: 250),
    alignment: 0.15,
    curve: Curves.easeOut,
  );
}

void _showServiceFeeDetails(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: 40,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            CustomText(
              text: 'Service fee details',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            SizedBox(height: 12),
            CustomText(
              text:
                  'Service fees help cover technical costs related to the transaction, ticket issuance, and data security. They are non-refundable.',
              fontSize: 14,
              color: Color(0xFF444444),
              height: 1.45,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PromoCodeCard extends StatefulWidget {
  const _PromoCodeCard({
    super.key,
    required this.controller,
    required this.eventId,
    required this.fallbackPrice,
  });

  final BuyTickerController controller;
  final String eventId;
  final String fallbackPrice;

  @override
  State<_PromoCodeCard> createState() => _PromoCodeCardState();
}

class _PromoCodeCardState extends State<_PromoCodeCard> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: widget.controller.promoCodeInput.value);
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Obx(() {
        final promo = controller.appliedPromo.value;
        final error = controller.promoError.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
              text: 'Promo code',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _field,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => controller.promoCodeInput.value = value,
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: controller.isValidatingPromo.value
                      ? null
                      : () => controller.applyPromo(
                          eventId: widget.eventId,
                          originalAmount: controller.eventSubtotal(
                            widget.fallbackPrice,
                          ),
                        ),
                  child: controller.isValidatingPromo.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFDCA73A),
                          ),
                        )
                      : const CustomText(
                          text: 'Apply',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDCA73A),
                        ),
                ),
              ],
            ),
            if (promo != null) ...[
              const SizedBox(height: 8),
              CustomText(
                text:
                    '${promo.code} applied · saved ${controller.formatEuro(promo.discountAmount)}',
                fontSize: 12,
                color: const Color(0xFFDCA73A),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              CustomText(text: error, fontSize: 12, color: Colors.redAccent),
            ],
          ],
        );
      }),
    );
  }
}
