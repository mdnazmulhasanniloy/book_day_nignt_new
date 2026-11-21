import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../club_details_view/views/event_details_view.dart';
import '../../club_details_view/widgets/club_community_section.dart';

class TrendingEventCard extends StatelessWidget {
  const TrendingEventCard({
    super.key,
    required this.event,
    required this.width,
  });
  final Map<String, dynamic> event;
  final double width;

  @override
  Widget build(BuildContext context) {
    final item = discoveryClub(event);
    final start = item.startAt?.toLocal();
    final end = item.endAt?.toLocal();
    final amount = _startingAmount(event);
    final currency = '${event['currency'] ?? ''}'.trim();
    final price = amount == null
        ? ''
        : amount == 0
        ? 'Free'
        : currency.isEmpty
        ? amount.toString()
        : NumberFormat.simpleCurrency(
            name: currency,
            decimalDigits: amount % 1 == 0 ? 0 : 2,
          ).format(amount);
    final timeLine = start == null
        ? ''
        : end == null
        ? '${DateFormat('d MMM').format(start)} · ${DateFormat('h:mm a').format(start)}'
        : '${DateFormat('d MMM').format(start)} · ${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}';

    return SizedBox(
      width: width,
      child: Material(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: item.id.isEmpty
              ? null
              : () => Get.to(
                  () => EventDetailsView(
                    clubModel: item.copyWith(price: price),
                  ),
                ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomNetworkImage(
                imageUrl: item.image,
                height: double.infinity,
                width: width,
                fit: BoxFit.cover,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x00000000),
                      Color(0xE6000000),
                    ],
                    stops: [0, 0.42, 1],
                  ),
                ),
              ),
              if (price.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: discoveryGold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      price,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (timeLine.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        timeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                    if (item.location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

num? _startingAmount(Map<String, dynamic> event) {
  final tiers = event['ticketTiers'] ?? event['tiers'];
  if (tiers is List) {
    final prices = <num>[];
    for (final row in tiers) {
      if (row is! Map) continue;
      final parsed = num.tryParse('${row['price']}');
      if (parsed != null) prices.add(parsed);
    }
    if (prices.isNotEmpty) {
      prices.sort();
      return prices.first;
    }
  }
  return num.tryParse('${event['eventPrice'] ?? event['price']}');
}
