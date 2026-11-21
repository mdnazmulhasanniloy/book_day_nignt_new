import 'package:flutter/material.dart';

import '../../../../core/resources/common_widget/custom_text.dart';
import '../model/promo_api_model.dart';

class PromoCodeCard extends StatelessWidget {
  const PromoCodeCard({
    super.key,
    required this.promo,
    this.onEdit,
    this.onDelete,
  });

  final PromoDataModel promo;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static const _gold = Color(0xFFDCA73A);
  static const _card = Color(0xFF161616);

  @override
  Widget build(BuildContext context) {
    final expired = promo.isExpired || !promo.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: expired ? Colors.white10 : _gold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomText(
                  text: promo.code.toUpperCase(),
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: expired
                      ? Colors.white10
                      : const Color(0xFF261D0A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CustomText(
                  text: expired ? 'Inactive' : promo.discountLabel,
                  color: expired ? Colors.white54 : _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CustomText(
            text: promo.appliesToLabel,
            color: Colors.white70,
            fontSize: 13,
          ),
          const SizedBox(height: 6),
          CustomText(
            text: promo.maxUses > 0
                ? 'Used ${promo.usedCount} of ${promo.maxUses}'
                : 'Used ${promo.usedCount}',
            color: Colors.white54,
            fontSize: 12,
          ),
          const SizedBox(height: 4),
          CustomText(
            text: promo.expiresAt == null
                ? 'No expiry'
                : 'Expires ${_formatDate(promo.expiresAt!)}',
            color: Colors.white38,
            fontSize: 12,
          ),
          // Promo code Edit & Delete buttons commented out as requested
          /*
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onEdit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: BorderSide(color: _gold.withValues(alpha: .55)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (onEdit != null && onDelete != null) const SizedBox(width: 10),
                if (onDelete != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE57373),
                        side: const BorderSide(color: Color(0x55E57373)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          */
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
