import 'package:bookdianight_app/app/core/network/api_expection.dart';
import 'package:bookdianight_app/app/core/utils/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../repository/stripe_connect_repository.dart';

class ConnectStatusModel {
  const ConnectStatusModel({
    required this.state,
    this.onboardingCompletedAt,
    required this.requiresOnboarding,
    required this.canCreateListings,
  });

  final String state;
  final String? onboardingCompletedAt;
  final bool requiresOnboarding;
  final bool canCreateListings;

  bool get isReady => state == 'READY' && canCreateListings;

  String get title {
    switch (state) {
      case 'IN_PROGRESS':
        return 'Continue setting up your account';
      case 'ACTION_REQUIRED':
        return 'Action required on your account';
      case 'READY':
        return 'Account verified';
      case 'RESTRICTED':
        return 'Account restricted';
      case 'SETUP_REQUIRED':
      default:
        return 'Set up your payout account';
    }
  }

  String get message {
    switch (state) {
      case 'IN_PROGRESS':
        return 'Your Stripe account exists, but setup is not finished. Continue in the browser to receive payouts.';
      case 'ACTION_REQUIRED':
        return 'Stripe needs more information before payouts can be sent to your account.';
      case 'READY':
        return 'Your payout account is verified. You can create clubs and events.';
      case 'RESTRICTED':
        return 'Stripe has restricted this account. Contact support before creating listings.';
      case 'SETUP_REQUIRED':
      default:
        return 'Connect your bank account with Stripe so BookdiaNight can pay out your earnings.';
    }
  }

  String get actionLabel {
    switch (state) {
      case 'IN_PROGRESS':
        return 'Continue setup';
      case 'ACTION_REQUIRED':
        return 'Update account';
      case 'READY':
        return 'Done';
      case 'RESTRICTED':
        return 'View status';
      case 'SETUP_REQUIRED':
      default:
        return 'Set up payout account';
    }
  }

  factory ConnectStatusModel.fromJson(Map<String, dynamic> json) {
    return ConnectStatusModel(
      state: json['state']?.toString() ?? 'SETUP_REQUIRED',
      onboardingCompletedAt: json['onboardingCompletedAt']?.toString(),
      requiresOnboarding: json['requiresOnboarding'] == true,
      canCreateListings: json['canCreateListings'] == true,
    );
  }
}

class StripeConnectController extends GetxController
    with WidgetsBindingObserver {
  StripeConnectController({StripeConnectRepository? repository})
    : _repository = repository ?? StripeConnectRepository();

  final StripeConnectRepository _repository;

  final status = Rxn<ConnectStatusModel>();
  final isLoading = false.obs;
  final isOpening = false.obs;
  var _awaitingBrowserReturn = false;

  static StripeConnectController ensure() {
    if (Get.isRegistered<StripeConnectController>()) {
      return Get.find<StripeConnectController>();
    }
    return Get.put(StripeConnectController(), permanent: true);
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    refreshStatus();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingBrowserReturn) {
      _awaitingBrowserReturn = false;
      refreshStatus();
    }
  }

  Future<ConnectStatusModel?> refreshStatus({bool notifyError = false}) async {
    isLoading.value = true;
    try {
      final next = ConnectStatusModel.fromJson(await _repository.fetchStatus());
      status.value = next;
      return next;
    } on ApiException catch (error) {
      if (notifyError) CustomSnackBar.error(message: error.message);
      return status.value;
    } catch (error) {
      if (notifyError) CustomSnackBar.error(message: error.toString());
      return status.value;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openOnboarding() async {
    if (isOpening.value) return;
    isOpening.value = true;
    try {
      final payload = await _repository.startOnboarding();
      final statusJson = payload['status'];
      final next = ConnectStatusModel.fromJson(
        statusJson is Map
            ? Map<String, dynamic>.from(statusJson)
            : payload,
      );
      status.value = next;
      final url = payload['onboardingUrl']?.toString().trim() ?? '';
      if (url.isEmpty) {
        if (next.isReady) {
          CustomSnackBar.success(message: 'Your payout account is ready.');
        } else if (next.state == 'RESTRICTED') {
          CustomSnackBar.warning(
            message: 'This payout account is restricted. Contact support.',
          );
        }
        return;
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        CustomSnackBar.error(message: 'Could not open the payout setup page.');
        return;
      }
      _awaitingBrowserReturn = true;
    } on ApiException catch (error) {
      CustomSnackBar.error(message: error.message);
    } catch (error) {
      CustomSnackBar.error(message: error.toString());
    } finally {
      isOpening.value = false;
    }
  }

  Future<bool> ensureCanCreateListings() async {
    final current = await refreshStatus(notifyError: true);
    return current?.canCreateListings == true;
  }
}
