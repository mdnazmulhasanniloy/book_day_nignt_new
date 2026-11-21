import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../resources/app_colors/app_colors.dart';
import '../resources/common_widget/custom_text.dart';
import 'network_checker.dart';

/// Shows a blocking dialog on this screen when the device has no network,
/// or the radio is on but there is no internet data.
class NetworkGuard extends StatefulWidget {
  const NetworkGuard({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkGuard> createState() => _NetworkGuardState();
}

class _NetworkGuardState extends State<NetworkGuard>
    with WidgetsBindingObserver {
  static var _dialogVisible = false;
  final _status = ValueNotifier<NetworkAvailability>(
    NetworkAvailability.online,
  );
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  var _token = 0;
  var _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = Connectivity().onConnectivityChanged.listen((_) {
      _refresh();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final token = ++_token;
    final availability = await NetworkChecker.check();
    if (!mounted || token != _token) return;
    _status.value = availability;
    if (availability == NetworkAvailability.online) return;
    _present();
  }

  void _present() {
    if (_dialogVisible || _dialogOpen || !mounted) return;
    _dialogVisible = true;
    _dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) =>
          _NetworkDialog(status: _status, onRetry: _refresh),
    ).whenComplete(() {
      _dialogOpen = false;
      _dialogVisible = false;
      if (!mounted) _status.dispose();
    });
  }

  @override
  void dispose() {
    _token++;
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_dialogOpen) {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    } else {
      _status.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NetworkDialog extends StatelessWidget {
  const _NetworkDialog({required this.status, required this.onRetry});

  final ValueNotifier<NetworkAvailability> status;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ValueListenableBuilder<NetworkAvailability>(
        valueListenable: status,
        builder: (context, availability, _) {
          if (availability == NetworkAvailability.online) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }

          final offline = availability != NetworkAvailability.noData;
          return Dialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    offline
                        ? Icons.wifi_off_rounded
                        : Icons.signal_cellular_connected_no_internet_4_bar,
                    color: AppColors.mainColor,
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  CustomText(
                    text: offline ? 'No network' : 'No internet data',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  CustomText(
                    text: offline
                        ? 'Your network is turned off. Please enable Wi-Fi or mobile data.'
                        : 'Network is on, but there is no data. Please check your SIM data or Wi-Fi connection.',
                    color: const Color(0xFFA0A0A0),
                    fontSize: 14,
                    textAlign: TextAlign.center,
                    maxLine: 4,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mainColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: NetworkChecker.openNetworkSettings,
                      child: const Text(
                        'Enable network',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
