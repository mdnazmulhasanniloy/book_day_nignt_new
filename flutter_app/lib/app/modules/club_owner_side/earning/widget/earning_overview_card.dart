import 'package:flutter/material.dart';
import '../../../../core/resources/common_widget/custom_text.dart';

class EarningOverviewCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;

  const EarningOverviewCard({
    super.key,
    required this.icon,
    required this.value,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    const Color cardBgColor = Color(0xFF161616);
    const Color primaryYellow = Color(0xFFDCA73A);
    const Color iconBgColor = Color(0xFF261D0A);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryYellow, size: 18),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CustomText(
                text: value,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryYellow,
                maxLine: 1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          CustomText(
            text: title,
            fontSize: 11,
            color: Colors.grey,
            maxLine: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
