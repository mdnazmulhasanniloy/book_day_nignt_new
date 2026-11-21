import '../views/trending_events_view.dart';
import 'home_reuseble.dart';
import 'home_shimmer.dart';
import 'trending_event_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/explore/repository/discovery_repository.dart';
import '../../../../core/network/end_point.dart';
import '../../club_details_view/widgets/club_community_section.dart';

class DiscoveryFeedController extends GetxController {
  DiscoveryFeedController({DiscoveryRepository? repository})
    : _repository = repository ?? DiscoveryRepository();

  final DiscoveryRepository _repository;
  final feed = <String, dynamic>{}.obs;
  final loading = false.obs;
  final error = RxnString();
  int _request = 0;

  List<Map<String, dynamic>> get blowingUp =>
      DiscoveryRepository.items(feed['blowingUp']);

  List<Map<String, dynamic>> get today =>
      DiscoveryRepository.items(feed['today']);

  List<Map<String, dynamic>> get tomorrow =>
      DiscoveryRepository.items(feed['tomorrow']);

  List<Map<String, dynamic>> get organizers =>
      DiscoveryRepository.items(feed['popularOrganizers']);

  List<String> get genres => DiscoveryRepository.strings(feed['genres']);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final request = ++_request;
    loading.value = true;
    error.value = null;
    try {
      final result = await _repository.get(EndPoint.exploreFeed);
      if (!isClosed && request == _request) {
        feed.assignAll(DiscoveryRepository.data(result));
      }
    } catch (_) {
      if (!isClosed && request == _request) {
        error.value = 'Could not load trending events';
      }
    } finally {
      if (!isClosed && request == _request) loading.value = false;
    }
  }
}

class DiscoveryFeedSection extends StatelessWidget {
  const DiscoveryFeedSection({super.key, required this.controller});
  final DiscoveryFeedController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final events = controller.blowingUp;
    final error = controller.error.value;
    final emptyFeed =
        events.isEmpty &&
        controller.today.isEmpty &&
        controller.tomorrow.isEmpty &&
        controller.organizers.isEmpty;

    if (error != null && emptyFeed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: TextButton(
          onPressed: controller.load,
          child: Text(
            '$error · Retry',
            style: const TextStyle(color: discoveryGold),
          ),
        ),
      );
    }

    if (controller.loading.value && emptyFeed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommonComponents.sectionHeader('Trending events', () {}),
            const SizedBox(height: 14),
            const HomeCarouselShimmer(tonight: false),
          ],
        ),
      );
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonComponents.sectionHeader(
            'Trending events',
            () => Get.to(
              () => TrendingEventsView(
                initialBlowingUp: events,
                initialToday: controller.today,
                initialTomorrow: controller.tomorrow,
                initialOrganizers: controller.organizers,
                initialGenres: controller.genres,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: CommonComponents.homeCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => TrendingEventCard(
                event: events[index],
                width: CommonComponents.homeCardWidth,
              ),
            ),
          ),
        ],
      ),
    );
  });
}
