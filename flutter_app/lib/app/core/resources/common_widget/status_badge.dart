import 'package:flutter/material.dart';
import 'custom_text.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  final String status;
  final String? label;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  static String formatLabel(String value) {
    if (value.isEmpty) return value;
    final lower = value.replaceAll('_', ' ').toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final key = status.trim().toUpperCase();
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final String text;

    switch (key) {
      case 'AVAILABLE':
      case 'CONFIRMED':
      case 'APPROVED':
        bgColor = const Color(0xFF0E2B18);
        borderColor = const Color(0xFF2E7D32);
        textColor = const Color(0xFF66BB6A);
        text = label ??
            (key == 'CONFIRMED' || key == 'APPROVED'
                ? 'Confirmed'
                : 'Available');
        break;
      case 'LIMITED':
      case 'PENDING':
        bgColor = const Color(0xFF2E1C06);
        borderColor = const Color(0xFFEF6C00);
        textColor = const Color(0xFFFFA726);
        text = label ?? (key == 'PENDING' ? 'Pending' : 'Limited');
        break;
      case 'SOLD_OUT':
      case 'SOLDOUT':
      case 'REJECTED':
        bgColor = const Color(0xFF2B0E10);
        borderColor = const Color(0xFFC62828);
        textColor = const Color(0xFFEF5350);
        text = label ?? (key == 'REJECTED' ? 'Rejected' : 'Sold out');
        break;
      case 'UNAVAILABLE':
      default:
        bgColor = const Color(0xFF212121);
        borderColor = const Color(0xFF616161);
        textColor = const Color(0xFFB0B0B0);
        text = label ?? (key.isEmpty ? 'Unavailable' : formatLabel(key));
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          CustomText(
            text: text,
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}

