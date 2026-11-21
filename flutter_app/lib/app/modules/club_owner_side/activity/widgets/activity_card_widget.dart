import 'package:flutter/material.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../controllers/owner_activity_controller.dart';

class ActivityCardWidget extends StatelessWidget {
  final ActivityItemModel item;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final bool isEditLoading;

  const ActivityCardWidget({
    super.key,
    required this.item,
    required this.onTap,
    this.onEdit,
    this.isEditLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryYellow = Color(0xFFDCA73A);
    final isEvent = item.type.toUpperCase() == 'EVENT';
    final schedule = isEvent ? _eventSchedule(item) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 248,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomNetworkImage(
              imageUrl: item.image,
              height: double.infinity,
              width: double.infinity,
              borderRadius: BorderRadius.circular(20),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0x99000000),
                    Color(0xF2000000),
                  ],
                  stops: [0.0, 0.38, 0.68, 1.0],
                ),
              ),
            ),
            if (onEdit != null)
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: isEditLoading ? null : onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryYellow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: isEditLoading
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.black, size: 13),
                              SizedBox(width: 4),
                              CustomText(
                                text: 'Edit',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildBadge(item.type),
                      const SizedBox(width: 7),
                      _buildBadge(
                        item.isActive ? 'Active' : 'Inactive',
                        textColor: item.isActive
                            ? const Color(0xFF66D19E)
                            : Colors.redAccent,
                        borderColor: item.isActive
                            ? const Color(0xFF66D19E)
                            : Colors.redAccent,
                      ),
                      if (item.isVip) ...[
                        const SizedBox(width: 7),
                        _buildBadge(
                          'VIP',
                          textColor: primaryYellow,
                          borderColor: primaryYellow,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomText(
                    text: item.title,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    maxLine: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (schedule != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: primaryYellow,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CustomText(
                            text: schedule,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            maxLine: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!item.isActive && item.deactivatedAt != null) ...[
                    const SizedBox(height: 4),
                    CustomText(
                      text:
                          'Deactivated: ${_dateTimeLabel(item.deactivatedAt!)}',
                      fontSize: 11,
                      color: Colors.redAccent,
                      maxLine: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: CustomText(
                          text: item.location,
                          fontSize: 12,
                          color: Colors.white70,
                          maxLine: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isEvent)
                        CustomText(
                          text: item.price,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryYellow,
                        )
                      else ...[
                        const Icon(
                          Icons.star_rounded,
                          color: primaryYellow,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        CustomText(
                          text: '${item.rating} • ${item.price}',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
    String text, {
    Color textColor = Colors.white,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? Colors.white24),
      ),
      child: CustomText(
        text: text,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }

  String? _eventSchedule(ActivityItemModel item) {
    final start = item.startAt;
    if (start == null || start.year < 2000) return null;
    final startLocal = start.toLocal();
    final end = item.endAt;
    if (end == null || end.year < 2000) {
      return '${_dateLabel(startLocal)} · ${_timeLabel(startLocal)}';
    }
    final endLocal = end.toLocal();
    final sameDay =
        startLocal.year == endLocal.year &&
        startLocal.month == endLocal.month &&
        startLocal.day == endLocal.day;
    if (sameDay) {
      return '${_dateLabel(startLocal)} · ${_timeLabel(startLocal)} – ${_timeLabel(endLocal)}';
    }
    return '${_dateLabel(startLocal)}, ${_timeLabel(startLocal)} – '
        '${_dateLabel(endLocal)}, ${_timeLabel(endLocal)}';
  }

  String _dateLabel(DateTime value) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[value.weekday - 1]}, ${months[value.month - 1]} ${value.day}';
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _dateTimeLabel(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour:$minute $period';
  }
}
