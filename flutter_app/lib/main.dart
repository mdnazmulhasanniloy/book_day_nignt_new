import 'dart:io';
import 'package:bookdianight_app/firebase_options.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get_storage/get_storage.dart';
import 'app/config/flavor_config.dart';
import 'app/core/language/app_translations.dart';
import 'app/core/local_storage/local_storage.dart';
import 'app/core/network/base_client.dart';
import 'app/core/network/end_point.dart';
import 'app/core/resources/app_const/app_const.dart';
import 'app/core/routes/app_pages.dart';
import 'app/core/routes/app_routes.dart';
import 'app/core/routes/not_found_page.dart';
import 'app/core/theme/app_theme.dart';
import 'app/core/utils/global_key.dart';
import 'app/core/utils/resource_const.dart';
import 'app/services/deep_link_service.dart';
import 'app/services/notification_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await GetStorage.init();
  await NotificationService().initNotification();
  debugPrint('fcmToken : ${await NotificationService().currentToken()}');

  /// dotenv
  await AppConfig.init();
  BaseClient().init(baseUrl: AppConfig.baseUrl);

  /// accessToken
  await GetStorage.init();
  debugPrint(
    'accessToken : ${LocalStorage.getData(key: AppConst.accessToken)}',
  );

  await AppConfig.init();
  final stripeKey = AppConfig.stripePublishableKey.trim();
  if (stripeKey.isNotEmpty) {
    Stripe.publishableKey = stripeKey;
    await Stripe.instance.applySettings();
  }

  HttpOverrides.global = MyHttpOverrides();
  BaseClient().init(
    baseUrl: EndPoint.BASE_URL,
    headers: {'Content-Type': 'application/json'},
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  );

  runApp(const MyApp());
  DeepLinkService.instance.init();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    String? savedLang = LocalStorage.getData(key: AppConst.languageCode);
    Locale startLocale = savedLang != null
        ? Locale(savedLang)
        : const Locale('en');

    Widget getApp(BuildContext context) {
      return GetMaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        enableLog: !AppConfig.isProduction,
        title: 'BookdiaNight',
        debugShowCheckedModeBanner: AppConfig.showDebugBanner,
        useInheritedMediaQuery: true,
        locale: AppConfig.isProduction
            ? startLocale
            : DevicePreview.locale(context),
        builder: (context, child) {
          if (!AppConfig.isProduction) {
            child = DevicePreview.appBuilder(context, child);
          }
          return child ?? const SizedBox.shrink();
        },
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // এই লাইনটির মাধ্যমে অ্যাপটি সবসময় Light Theme-এ চলবে
        // themeMode: themeService.theme,
        themeMode: ThemeMode.light,
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        defaultTransition: Transition.fade,
        popGesture: true,
        smartManagement: SmartManagement.keepFactory,
        navigatorObservers: [GetObserver()],
        unknownRoute: GetPage(
          name: AppRoutes.notFound,
          page: () => const NotFoundPage(),
        ),
        fallbackLocale: const Locale('en', 'US'),
        translations: AppTranslations(),
      );
    }

    if (AppConfig.isProduction) {
      return getApp(context);
    } else {
      return DevicePreview(
        enabled: true,
        builder: (context) => getApp(context),
      );
    }
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
