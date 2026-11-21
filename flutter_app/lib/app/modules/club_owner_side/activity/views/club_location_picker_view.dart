import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../model/club_location_model.dart';
import '../repository/club_location_repository.dart';

class ClubLocationPickerView extends StatefulWidget {
  const ClubLocationPickerView({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<ClubLocationPickerView> createState() => _ClubLocationPickerViewState();
}

class _ClubLocationPickerViewState extends State<ClubLocationPickerView> {
  static const _dhaka = LatLng(23.8103, 90.4125);
  final ClubLocationRepository _repository = ClubLocationRepository();

  GoogleMapController? _mapController;
  late LatLng _selectedPoint;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    final latitude = widget.initialLatitude;
    final longitude = widget.initialLongitude;
    _selectedPoint =
        latitude != null &&
            longitude != null &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180 &&
            (latitude != 0 || longitude != 0)
        ? LatLng(latitude, longitude)
        : _dhaka;
  }

  Future<void> _confirmLocation() async {
    setState(() => _isResolving = true);
    try {
      final address = await _repository.addressFromCoordinates(
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
      );
      if (!mounted) return;
      Get.back(
        result: ClubLocationSelectionModel(
          address: address,
          latitude: _selectedPoint.latitude,
          longitude: _selectedPoint.longitude,
        ),
      );
    } catch (_) {
      CustomSnackBar.error(message: 'Could not identify this map location.');
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0D0D0D);
    const primary = Color(0xFFDCA73A);

    return Scaffold(
      backgroundColor: background,
      appBar: const CustomAppBar(
        title: 'Select Club Location',
        backgroundColor: background,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPoint,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('selected-club-location'),
                position: _selectedPoint,
              ),
            },
            onMapCreated: (controller) => _mapController = controller,
            onTap: (point) => setState(() => _selectedPoint = point),
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_outlined, color: primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: CustomText(
                      text: 'Tap anywhere on the map to place the club marker',
                      color: Colors.white,
                      fontSize: 12,
                      maxLine: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 96,
            child: Column(
              children: [
                _MapActionButton(
                  icon: Icons.add,
                  onTap: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 10),
                _MapActionButton(
                  icon: Icons.remove,
                  onTap: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomOut()),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: CustomButton(
                  title: 'Use This Location',
                  isLoading: _isResolving,
                  buttonColor: primary,
                  titleColor: Colors.black,
                  isGradient: false,
                  borderRadius: 16,
                  paddingVertical: 0,
                  onTap: _confirmLocation,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B1B1B),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: 46,
          width: 46,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
