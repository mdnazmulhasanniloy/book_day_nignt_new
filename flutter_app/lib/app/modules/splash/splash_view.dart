import 'package:bookdianight_app/app/core/local_storage/local_storage.dart';
import 'package:bookdianight_app/app/core/location/auth_coordinates.dart';
import 'package:bookdianight_app/app/core/network/api_expection.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:bookdianight_app/app/core/resources/common_style/responsive_helper.dart';
import 'package:bookdianight_app/app/core/routes/app_routes.dart';
import 'package:bookdianight_app/app/core/utils/device_helper.dart';
import 'package:bookdianight_app/app/modules/authentication/auth_repository/auth_repository.dart';
import 'package:bookdianight_app/app/services/notification_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/location/location_access.dart';
import '../../core/resources/app_assets/app_assets.dart';
import '../club_owner_side/dashboard/dashboard/owner_dashboard.dart';
import '../club_owner_side/stripe_connect/controllers/stripe_connect_controller.dart';
import '../club_owner_side/stripe_connect/views/payout_setup_view.dart';
import '../user_side/dashboard/user_dashboard.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigate();
    });
  }

  Future<void> _navigate() async {
    await LocationAccess.ensure(context);
    if (!mounted) return;

    var token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    final role = LocalStorage.getData(key: AppConst.role);

    if (token != null && token.isNotEmpty) {
      token = await _refreshSession(token);
    }

    if (token != null && token.isNotEmpty) {
      if (role == 'CLUB_OWNER') {
        final status = await StripeConnectController.ensure().refreshStatus();
        if (!mounted) return;
        if (status?.canCreateListings == true) {
          Get.offAll(() => const OwnerDashboard());
        } else {
          Get.offAll(() => const PayoutSetupView());
        }
      } else {
        Get.offAll(() => const UserDashboard());
      }
    } else {
      Get.offNamed(AppRoutes.onboarding);
    }
  }

  Future<String?> _refreshSession(String token) async {
    try {
      final fcmToken = await NotificationService().currentToken();
      final coords = await AuthCoordinates.read();
      final response = await AuthRepository().checkAuth(
        deviceIdentifier: DeviceHelper.getDeviceIdentifier(),
        platform: DeviceHelper.getPlatform(),
        lat: coords.lat,
        lng: coords.lng,
        fcmToken: fcmToken,
        token: token,
      );
      final body = response.data;
      if (body is Map && body['success'] == false) {
        await LocalStorage.removeData(key: AppConst.accessToken);
        await LocalStorage.removeData(key: AppConst.role);
        return null;
      }
      return token;
    } on UnauthorizedException {
      await LocalStorage.removeData(key: AppConst.accessToken);
      await LocalStorage.removeData(key: AppConst.role);
      return null;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await LocalStorage.removeData(key: AppConst.accessToken);
        await LocalStorage.removeData(key: AppConst.role);
        return null;
      }
      return token;
    } catch (_) {
      return token;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFFC88E02).withValues(alpha: 0.20),
                    const Color(0xFFC88E02).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Image.asset(
              AppAssets.appLogo,
              height: context.s.mtd(300, 600, 800),
              width: context.s.mtd(300, 600, 800),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
