import 'package:flutter/material.dart';

import '../../../../core/resources/common_widget/custom_text.dart';

class CommonComponents {
  static const double homeCardWidth = 236;
  static const double homeCardHeight = 188;

  static Widget buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: CustomText(
        text: text,
        fontSize: 6,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        maxLine: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Section Title এবং 'See all' বাটনের জন্য
  static Widget sectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      children: [
        Expanded(
          child: CustomText(
            text: title,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            maxLine: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onSeeAll,
          child: const Row(
            children: [
              CustomText(
                text: 'See all',
                fontSize: 12,
                color: Color(0xFFE1B144),
                fontWeight: FontWeight.w600,
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                color: Color(0xFFE1B144),
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
