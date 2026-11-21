import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../club_details_view/views/club_details_view.dart';
import '../../home/controllers/club_controller.dart';
import '../../home/controllers/user_location_controller.dart';

class MapOverviewController extends GetxController {
  MapOverviewController({required this.venues});

  final List<ClubModel> venues;
  final Completer<GoogleMapController> mapController =
      Completer<GoogleMapController>();
  final markers = <Marker>{}.obs;
  final isLoadingMarkers = true.obs;
  final selectedVenue = Rxn<ClubModel>();
  final selectedDistanceLabel = ''.obs;

  late final Future<void> _markerLoad;
  final Map<String, ClubModel> _venuesByMarkerId = {};

  List<ClubModel> get _venuesWithCoordinates => venues
      .where(
        (venue) =>
            venue.latitude != null &&
            venue.longitude != null &&
            venue.latitude != 0 &&
            venue.longitude != 0,
      )
      .toList(growable: false);

  CameraPosition get initialPosition {
    final items = _venuesWithCoordinates;
    if (items.isEmpty) {
      return const CameraPosition(target: LatLng(23.7808, 90.4076), zoom: 11);
    }

    final latitude =
        items.fold<double>(0, (sum, venue) => sum + venue.latitude!) /
        items.length;
    final longitude =
        items.fold<double>(0, (sum, venue) => sum + venue.longitude!) /
        items.length;
    return CameraPosition(target: LatLng(latitude, longitude), zoom: 12);
  }

  @override
  void onInit() {
    super.onInit();
    _markerLoad = _createVenueMarkers();
    _ensureCurrentLocation();
  }

  Future<void> _ensureCurrentLocation() async {
    final locationController = Get.isRegistered<UserLocationController>()
        ? Get.find<UserLocationController>()
        : Get.put(UserLocationController());
    if (locationController.currentLocation.value?.isAvailable != true) {
      await locationController.loadCurrentLocation();
    }
  }

  Future<void> _createVenueMarkers() async {
    isLoadingMarkers.value = true;
    _venuesByMarkerId.clear();

    final venueMarkers = await Future.wait(
      _venuesWithCoordinates.map((venue) async {
        final markerId = venue.id.isNotEmpty
            ? venue.id
            : '${venue.title}-${venue.latitude}-${venue.longitude}';
        _venuesByMarkerId[markerId] = venue;

        final icon = await _circularImageMarker(
          venue.image,
          const Color(0xFFE1B144),
        );

        return Marker(
          markerId: MarkerId(markerId),
          position: LatLng(venue.latitude!, venue.longitude!),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow.noText,
          onTap: () => selectVenue(venue),
        );
      }),
    );
    markers.assignAll(venueMarkers);
    isLoadingMarkers.value = false;

    if (mapController.isCompleted) {
      await fitAllVenues();
    }
  }

  void selectVenue(ClubModel venue) {
    selectedVenue.value = venue;
    selectedDistanceLabel.value = distanceLabelFor(venue);
  }

  void clearSelection() {
    selectedVenue.value = null;
    selectedDistanceLabel.value = '';
  }

  void openSelectedDetails() {
    final venue = selectedVenue.value;
    if (venue == null) return;
    Get.to(
      () => ClubDetailsView(
        clubModel: venue,
        isFavorite: venue.isWishlist,
      ),
    );
  }

  String distanceLabelFor(ClubModel venue) {
    final locationController = Get.isRegistered<UserLocationController>()
        ? Get.find<UserLocationController>()
        : null;
    final current = locationController?.currentLocation.value;
    if (current?.isAvailable != true ||
        venue.latitude == null ||
        venue.longitude == null) {
      return 'Distance unavailable';
    }

    final km = _distanceInKm(
      current!.latitude!,
      current.longitude!,
      venue.latitude!,
      venue.longitude!,
    );

    if (km < 1) {
      return '${(km * 1000).round()} m away';
    }
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
  }

  double _distanceInKm(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadius = 6371.0;
    final latitudeDistance = _toRadians(secondLatitude - firstLatitude);
    final longitudeDistance = _toRadians(secondLongitude - firstLongitude);
    final value =
        math.sin(latitudeDistance / 2) * math.sin(latitudeDistance / 2) +
        math.cos(_toRadians(firstLatitude)) *
            math.cos(_toRadians(secondLatitude)) *
            math.sin(longitudeDistance / 2) *
            math.sin(longitudeDistance / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  Future<BitmapDescriptor> _circularImageMarker(
    String imageUrl,
    Color borderColor,
  ) async {
    ui.Image? venueImage;
    if (imageUrl.trim().isNotEmpty) {
      try {
        final separator = imageUrl.contains('?') ? '&' : '?';
        final resizedUrl =
            '$imageUrl${separator}auto=format&fit=crop&w=240&h=240&q=80';
        final uri = Uri.parse(resizedUrl);
        final imageData = await NetworkAssetBundle(uri).load(uri.toString());
        final codec = await ui.instantiateImageCodec(
          imageData.buffer.asUint8List(),
          targetWidth: 140,
          targetHeight: 140,
        );
        venueImage = (await codec.getNextFrame()).image;
      } catch (_) {
        venueImage = null;
      }
    }

    const canvasSize = 152.0;
    const center = Offset(canvasSize / 2, canvasSize / 2);
    const outerRadius = 70.0;
    const innerRadius = 62.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      center + const Offset(0, 3),
      outerRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, outerRadius, Paint()..color = borderColor);
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()..color = const Color(0xFF292929),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius)),
    );
    if (venueImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: center, radius: innerRadius),
        image: venueImage,
        fit: BoxFit.cover,
      );
    } else {
      _drawEmptyImageIcon(canvas, center);
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final picture = recorder.endRecording();
    final markerImage = await picture.toImage(
      canvasSize.toInt(),
      canvasSize.toInt(),
    );
    final bytes = await markerImage.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not create marker image');

    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: 52,
      height: 52,
    );
  }

  void _drawEmptyImageIcon(Canvas canvas, Offset center) {
    final icon = Icons.image_outlined;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 58,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  Future<void> onMapCreated(GoogleMapController controller) async {
    if (!mapController.isCompleted) {
      mapController.complete(controller);
    }
    await _markerLoad;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await fitAllVenues();
  }

  Future<void> fitAllVenues() async {
    final items = _venuesWithCoordinates;
    if (items.isEmpty || !mapController.isCompleted) return;
    final controller = await mapController.future;

    if (items.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(items.first.latitude!, items.first.longitude!),
            zoom: 15,
          ),
        ),
      );
      return;
    }

    var minLatitude = items.first.latitude!;
    var maxLatitude = items.first.latitude!;
    var minLongitude = items.first.longitude!;
    var maxLongitude = items.first.longitude!;
    for (final venue in items.skip(1)) {
      minLatitude = venue.latitude! < minLatitude
          ? venue.latitude!
          : minLatitude;
      maxLatitude = venue.latitude! > maxLatitude
          ? venue.latitude!
          : maxLatitude;
      minLongitude = venue.longitude! < minLongitude
          ? venue.longitude!
          : minLongitude;
      maxLongitude = venue.longitude! > maxLongitude
          ? venue.longitude!
          : maxLongitude;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLatitude, minLongitude),
          northeast: LatLng(maxLatitude, maxLongitude),
        ),
        70,
      ),
    );
  }

  Future<void> zoomIn() async {
    final controller = await mapController.future;
    await controller.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> zoomOut() async {
    final controller = await mapController.future;
    await controller.animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> goToCurrentLocation() async {
    final locationController = Get.isRegistered<UserLocationController>()
        ? Get.find<UserLocationController>()
        : Get.put(UserLocationController());
    final location =
        locationController.currentLocation.value?.isAvailable == true
        ? locationController.currentLocation.value!
        : await locationController.loadCurrentLocation();
    if (!location.isAvailable) return;

    final controller = await mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(location.latitude!, location.longitude!),
          zoom: 14,
        ),
      ),
    );
  }

  String get darkMapStyle => '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2c2c2c"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}
  ]
  ''';
}
