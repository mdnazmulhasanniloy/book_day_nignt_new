import 'package:flutter/material.dart';
import '../../../core/resources/app_assets/app_assets.dart';
import '../../../core/resources/app_colors/App_Colors.dart';
import '../../../core/resources/common_style/extention.dart';
import '../../../core/resources/common_widget/custom_text.dart';
import '../../../core/extentions/theme_extention.dart';
import '../model/notification_model.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel data;
  final VoidCallback onTap;

  const NotificationCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          // Visual cue: Change color or border if unread
            color: data.isRead ? context.inputColor : context.inputColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: data.isRead ? context.borderColor : AppColors.mainColor.withValues(alpha: 0.5)
            )
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CircleAvatar(
                backgroundColor: data.isRead ? Colors.grey : AppColors.mainColor,
                child: Image.asset(
                  AppAssets.notificationIcon,
                  width: 20,
                  height: 20,
                  color: Colors.white,
                ),
              ),
            ),
            12.widthBox,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: data.title,
                    fontWeight: data.isRead ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                    maxLine: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data.subtitle.trim().isNotEmpty) ...[
                    4.heightBox,
                    CustomText(
                      text: data.subtitle,
                      fontSize: 12,
                      color: data.isRead ? Colors.white60 : Colors.white70,
                      height: 1.35,
                    ),
                  ],
                  if (data.when.trim().isNotEmpty) ...[
                    6.heightBox,
                    CustomText(
                      text: data.when,
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ],
                ],
              ),
            ),
            // Unread dot indicator
            if (!data.isRead) ...[
              8.widthBox,
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: CircleAvatar(radius: 4, backgroundColor: AppColors.mainColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
