import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../local_storage/local_storage.dart';
import '../resources/app_const/app_const.dart';
import '../resources/common_widget/custom_button.dart';
import '../resources/common_widget/custom_text.dart';
import '../../modules/user_side/home/repository/location_repository.dart';

class LocationAccess {
  static Future<void> ensure(BuildContext context) async {
    final repository = LocationRepository();
    while (context.mounted) {
      final enabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (enabled && granted) {
        final stored = await _store(repository);
        if (stored) return;
      }
      if (!context.mounted) return;

      final openSettings =
          !enabled || permission == LocationPermission.deniedForever;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: const Color(0xFF161616),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFE1B144),
                      size: 46,
                    ),
                    const SizedBox(height: 16),
                    const CustomText(
                      text: 'Location access',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    CustomText(
                      text: openSettings
                          ? 'Location is required. Turn it on in settings to continue.'
                          : 'Allow location so we can show clubs near you and complete sign in.',
                      fontSize: 14,
                      color: Colors.white70,
                      textAlign: TextAlign.center,
                      height: 1.45,
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      title: openSettings ? 'Open settings' : 'Allow',
                      buttonColor: const Color(0xFFE1B144),
                      titleColor: Colors.black,
                      isGradient: false,
                      borderRadius: 16,
                      onTap: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (!context.mounted) return;
      if (!await Geolocator.isLocationServiceEnabled()) {
        final opened = await Geolocator.openLocationSettings();
        if (opened) await _waitUntilResumed();
        continue;
      }
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        final opened = await Geolocator.openAppSettings();
        if (opened) await _waitUntilResumed();
        continue;
      }
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final stored = await _store(repository);
        if (stored) return;
      }
    }
  }

  static Future<void> _waitUntilResumed() {
    final completer = Completer<void>();
    var finished = false;
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        if (finished) return;
        finished = true;
        listener.dispose();
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        if (finished) return;
        finished = true;
        listener.dispose();
      },
    );
  }

  static Future<bool> _store(LocationRepository repository) async {
    final location = await repository.getCurrentLocation();
    if (!location.isAvailable) return false;
    await LocalStorage.saveData(
      key: AppConst.currentLocation,
      data: location.toJson(),
    );
    return true;
  }
}
