import '../../../../core/resources/common_widget/address_from_coordinates.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../home/controllers/club_controller.dart';
import '../controllers/map_overview_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapOverviewScreen extends StatefulWidget {
  const MapOverviewScreen({super.key, required this.venues});

  final List<ClubModel> venues;

  @override
  State<MapOverviewScreen> createState() => _MapOverviewScreenState();
}

class _MapOverviewScreenState extends State<MapOverviewScreen> {
  static const _primary = Color(0xFFE1B144);
  late final MapOverviewController controller;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<MapOverviewController>()) {
      Get.delete<MapOverviewController>();
    }
    controller = Get.put(MapOverviewController(venues: widget.venues));
  }

  @override
  void dispose() {
    if (Get.isRegistered<MapOverviewController>()) {
      Get.delete<MapOverviewController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Map Overview',
        centerTitle: true,
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: InkWell(
            onTap: () => Get.back(),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Obx(
            () => GoogleMap(
              initialCameraPosition: controller.initialPosition,
              style: controller.darkMapStyle,
              markers: controller.markers.toSet(),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: true,
              mapToolbarEnabled: false,
              onMapCreated: controller.onMapCreated,
              onTap: (_) => controller.clearSelection(),
            ),
          ),
          Obx(
            () => controller.isLoadingMarkers.value
                ? const Positioned(
                    left: 0,
                    right: 0,
                    top: 110,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            right: 16,
            top: 140,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.add,
                  onTap: controller.zoomIn,
                  backgroundColor: const Color(0xFF2C241B),
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.remove,
                  onTap: controller.zoomOut,
                  backgroundColor: const Color(0xFF2C241B),
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.center_focus_strong_rounded,
                  onTap: controller.fitAllVenues,
                  backgroundColor: const Color(0xFF2C241B),
                ),
                const SizedBox(height: 24),
                _MapControlButton(
                  icon: Icons.my_location,
                  onTap: controller.goToCurrentLocation,
                  backgroundColor: const Color(0xFFFF5227),
                ),
              ],
            ),
          ),
          Obx(() {
            final venue = controller.selectedVenue.value;
            if (venue == null) return const SizedBox.shrink();
            return Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: _SelectedVenueCard(
                venue: venue,
                distanceLabel: controller.selectedDistanceLabel.value,
                onTap: controller.openSelectedDetails,
                onClose: controller.clearSelection,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SelectedVenueCard extends StatelessWidget {
  const _SelectedVenueCard({
    required this.venue,
    required this.distanceLabel,
    required this.onTap,
    required this.onClose,
  });

  final ClubModel venue;
  final String distanceLabel;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CustomNetworkImage(
                  imageUrl: venue.image,
                  height: 78,
                  width: 78,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: CustomText(
                              text: venue.type,
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onClose,
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CustomText(
                        text: venue.title,
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      AddressFromCoordinates(
                        lat: venue.latitude,
                        lng: venue.longitude,
                        existingAddress: venue.location,
                        color: Colors.white54,
                        fontSize: 12,
                        maxLine: 1,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_outlined,
                            color: Color(0xFFE1B144),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: CustomText(
                              text: distanceLabel,
                              color: const Color(0xFFE1B144),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              maxLine: 1,
                            ),
                          ),
                          if (venue.price.isNotEmpty)
                            CustomText(
                              text: venue.isEvent
                                  ? venue.price
                                  : 'From ${venue.price}',
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
