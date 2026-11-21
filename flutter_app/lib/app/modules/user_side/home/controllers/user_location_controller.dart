import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../model/current_location_model.dart';
import '../repository/location_repository.dart';

class UserLocationController extends GetxController {
  UserLocationController({LocationRepository? repository})
    : _repository = repository ?? LocationRepository();

  final LocationRepository _repository;

  final currentLocation = Rxn<CurrentLocationModel>();
  final isLoading = false.obs;
  Future<CurrentLocationModel>? _inFlight;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCurrentLocation();
    });
  }

  Future<CurrentLocationModel> loadCurrentLocation() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _load();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<CurrentLocationModel> _load() async {
    isLoading.value = true;
    try {
      final location = await _repository.getCurrentLocation();
      currentLocation.value = location;
      if (location.isAvailable) {
        await LocalStorage.saveData(
          key: AppConst.currentLocation,
          data: location.toJson(),
        );
      }
      return location;
    } finally {
      isLoading.value = false;
    }
  }
}
