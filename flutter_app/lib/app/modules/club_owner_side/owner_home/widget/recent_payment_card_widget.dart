import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/resources/common_widget/custom_text.dart';
import '../repository/owner_stats_repository.dart';

class RecentPaymentCardWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final VoidCallback? onTap;

  const RecentPaymentCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);
    const Color greenColor = Color(0xFF2D6A4F);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.credit_card, color: primaryYellow),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: title,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  maxLine: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                CustomText(
                  text: subtitle,
                  fontSize: 12,
                  color: Colors.grey,
                  maxLine: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: greenColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CustomText(
                  text: amount,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  maxLine: 1,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

void showOwnerPaymentDialog(OwnerPaymentItem payment) {
  const gold = Color(0xFFE1B144);
  Get.dialog(
    Dialog(
      backgroundColor: const Color(0xFF141414),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: gold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: CustomText(
                    text: 'Payment details',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
            CustomText(
              text: payment.title,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            const SizedBox(height: 14),
            _PaymentDetailRow(label: 'Type', value: payment.typeLabel),
            if (payment.eventName.isNotEmpty)
              _PaymentDetailRow(label: 'Event', value: payment.eventName)
            else if (payment.clubName.isNotEmpty)
              _PaymentDetailRow(label: 'Club', value: payment.clubName),
            if (payment.type == 'EVENT') ...[
              if (payment.title.isNotEmpty)
                _PaymentDetailRow(
                  label: 'Ticket / Tier',
                  value: payment.title,
                ),
            ] else ...[
              if (payment.tierName.isNotEmpty && payment.tierName != payment.clubName)
                _PaymentDetailRow(
                  label: 'Table / Package',
                  value: payment.tierName,
                )
              else if (payment.title.isNotEmpty && payment.title != payment.clubName)
                _PaymentDetailRow(
                  label: 'Table / Package',
                  value: payment.title,
                ),
            ],
            _PaymentDetailRow(label: 'Customer', value: payment.customerLabel),
            _PaymentDetailRow(label: 'Date', value: payment.dateLabel),
            _PaymentDetailRow(
              label: 'Amount',
              value: payment.amountLabel,
              valueColor: gold,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaymentDetailRow extends StatelessWidget {
  const _PaymentDetailRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: CustomText(text: label, fontSize: 13, color: Colors.white60),
          ),
          Expanded(
            child: CustomText(
              text: value,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
