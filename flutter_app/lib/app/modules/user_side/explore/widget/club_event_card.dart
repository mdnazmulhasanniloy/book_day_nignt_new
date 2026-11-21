import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/resources/common_widget/address_from_coordinates.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../favorite/controllers/wishlist_controller.dart';
import '../../home/controllers/club_controller.dart';

class ClubEventCard extends StatelessWidget {
  final ClubModel club;
  final double? width;
  final bool? isFavoriteBadgeShow;
  final bool? isFavorite;
  final double imageHeight;
  final VoidCallback? onFavoriteTap;
  final bool ratingAsBadge;

  const ClubEventCard({
    super.key,
    required this.club,
    this.width,
    this.isFavoriteBadgeShow = true,
    this.isFavorite,
    this.imageHeight = 240,
    this.onFavoriteTap,
    this.ratingAsBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final wishlistController = Get.isRegistered<WishlistController>()
        ? Get.find<WishlistController>()
        : Get.put(WishlistController(), permanent: true);

    final compact = ratingAsBadge;
    return Container(
      width: width ?? double.infinity,
      height: imageHeight,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomNetworkImage(
            imageUrl: club.image,
            height: double.infinity,
            width: double.infinity,
            borderRadius: BorderRadius.circular(18),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: isFavoriteBadgeShow == true
                ? Obx(() {
                    final favorited =
                        isFavorite ?? wishlistController.isWishlisted(club);
                    final busy = wishlistController.isToggling(club);
                    return GestureDetector(
                      onTap: busy
                          ? null
                          : (onFavoriteTap ??
                                () => wishlistController.toggle(club)),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                favorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: favorited ? Colors.red : Colors.white,
                                size: 22,
                              ),
                      ),
                    );
                  })
                : const SizedBox.shrink(),
          ),
          Positioned(
            bottom: 15,
            left: 15,
            right: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildBadge(club.type, compact: compact),
                    if (compact && club.hasRating && !club.isEvent) ...[
                      const SizedBox(width: 6),
                      _buildRatingBadge(club.rating, compact: true),
                    ],
                    if (compact && club.price.isNotEmpty) ...[
                      const Spacer(),
                      _buildPriceBadge(
                        club.price.startsWith('From ')
                            ? club.price
                            : 'From ${club.price}',
                      ),
                    ],
                  ],
                ),
                SizedBox(height: club.isEvent ? 4 : compact ? 8 : 10),
                CustomText(
                  text: club.title,
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: club.isEvent ? 1.15 : null,
                  maxLine: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (club.isEvent && _eventSchedule(club) != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Color(0xFFE1B144),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CustomText(
                          text: _eventSchedule(club)!,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                          color: Colors.white,
                          maxLine: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: club.isEvent ? 2 : compact ? 4 : 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: compact ? 1 : 0),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: Colors.white54,
                        size: compact ? 14 : 18,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: AddressFromCoordinates(
                        lat: club.latitude,
                        lng: club.longitude,
                        existingAddress: club.location,
                        color: Colors.white70,
                        fontSize: compact ? 11 : 14,
                        maxLine: 1,
                      ),
                    ),
                    if (!compact && club.hasRating) ...[
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 2),
                      CustomText(
                        text: club.rating,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        maxLine: 1,
                      ),
                    ],
                    if (!compact && club.price.isNotEmpty) ...[
                      if (club.hasRating)
                        const CustomText(
                          text: ' • ',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      CustomText(
                        text: club.price.startsWith('From ')
                            ? club.price
                            : 'From ${club.price}',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        maxLine: 1,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _eventSchedule(ClubModel club) {
    final start = club.startAt;
    if (start == null || start.year < 2000) return null;
    final startLocal = start.toLocal();
    final end = club.endAt;
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

  Widget _buildPriceBadge(String price) {
    const gold = Color(0xFFE1B144);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: gold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomText(
        text: price,
        fontSize: 10,
        color: Colors.black,
        fontWeight: FontWeight.w700,
        maxLine: 1,
      ),
    );
  }

  Widget _buildRatingBadge(String rating, {bool compact = false}) {
    const gold = Color(0xFFE1B144);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: gold, size: compact ? 11 : 13),
          const SizedBox(width: 3),
          CustomText(
            text: rating,
            fontSize: compact ? 10 : 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            maxLine: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: CustomText(
        text: text,
        fontSize: compact ? 10 : 12,
        color: Colors.white,
        fontWeight: FontWeight.w500,
        maxLine: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
