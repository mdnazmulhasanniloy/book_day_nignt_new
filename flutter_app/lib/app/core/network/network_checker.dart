import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum NetworkAvailability { online, offline, noData }

class NetworkChecker {
  NetworkChecker._();

  static const _settingsChannel = MethodChannel('bookdianight/network');

  static Future<NetworkAvailability> check() async {
    final List<ConnectivityResult> results;
    try {
      results = await Connectivity().checkConnectivity();
    } catch (_) {
      return NetworkAvailability.online;
    }

    final hasInterface = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn,
    );
    if (!hasInterface) return NetworkAvailability.offline;

    final reachable = await _canReachInternet();
    if (!reachable) return NetworkAvailability.noData;
    return NetworkAvailability.online;
  }

  static Future<bool> _canReachInternet() async {
    const targets = <(String, int)>[('1.1.1.1', 443), ('8.8.8.8', 53)];
    for (final target in targets) {
      try {
        final socket = await Socket.connect(
          target.$1,
          target.$2,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<void> openNetworkSettings() async {
    if (Platform.isAndroid) {
      try {
        await _settingsChannel.invokeMethod('openWirelessSettings');
        return;
      } catch (_) {}
    }
    await openAppSettings();
  }
}
