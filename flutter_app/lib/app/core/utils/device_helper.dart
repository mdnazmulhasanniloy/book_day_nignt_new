import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/local_storage/local_storage.dart';

class DeviceHelper {
  static const String _keyDeviceIdentifier = 'deviceIdentifier';

  /// Generates or retrieves a unique persistent device identifier
  static String getDeviceIdentifier() {
    String? existingId = LocalStorage.getData(key: _keyDeviceIdentifier);
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    // Generate a unique identifier if not present
    String newId =
        "device_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}";
    LocalStorage.saveData(key: _keyDeviceIdentifier, data: newId);
    return newId;
  }

  static String getPlatform() {
    return defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
  }
}
