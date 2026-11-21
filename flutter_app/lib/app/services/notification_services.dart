import 'notification_router.dart';
import 'package:get/get.dart';
import '../modules/notification/controller/notification_controller.dart';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../core/local_storage/local_storage.dart';

// ─── 1. Top-Level Background Handler (For handling messages when the app is terminated/background) ───
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- 🖨️ Print Push Notification Data (Background/Terminated) ---
  debugPrint('🔔 [BACKGROUND PUSH NOTIFICATION RECEIVED] 🔔');
  debugPrint('Message ID: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Payload/Data: ${message.data}');
  debugPrint('──────────────────────────────────────────');
}

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // High Importance Channel for Android
  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.max,
    playSound: true,
  );

  Future<void> initNotification() async {
    // ─── 2. Request Permissions (For iOS & Android 13+) ───
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (!kIsWeb && Platform.isIOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Request local notification permissions specifically for Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidImplementation?.requestNotificationsPermission();

    // ─── 3. Local Notification Initialization ───
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // Initialize using Named Arguments (v22.0.0 syntax)
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Triggered when a local notification is tapped in the foreground
        if (response.payload != null) {
          _handleNotificationClick(jsonDecode(response.payload!));
        }
      },
    );

    // Create the notification channel (Android only)
    await androidImplementation?.createNotificationChannel(_channel);

    _setupFCMListeners();
    await _saveDeviceToken();
    _fcm.onTokenRefresh.listen(_saveToken);
  }

  Future<String> currentToken() async {
    final fresh = await getDeviceToken();
    if (fresh != null && fresh.trim().isNotEmpty) {
      await _saveToken(fresh.trim());
      return fresh.trim();
    }
    final saved =
        LocalStorage.getData(key: 'fcmToken')?.toString().trim() ?? '';
    if (saved.isEmpty || saved == 'sample_fcm_token_123456') return '';
    return saved;
  }

  Future<void> _saveDeviceToken() async {
    await currentToken();
  }

  Future<void> _saveToken(String token) async {
    await LocalStorage.saveData(key: 'fcmToken', data: token);
  }

  void _setupFCMListeners() {
    // A. When the app is open (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (Get.isRegistered<NotificationController>()) {
        Get.find<NotificationController>().refreshUnreadCount();
      }

      // --- 🖨️ Print Push Notification Data (Foreground) ---
      debugPrint('🔔 [FOREGROUND PUSH NOTIFICATION RECEIVED] 🔔');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Payload/Data: ${message.data}');
      debugPrint('──────────────────────────────────────────');

      final title =
          message.notification?.title ??
          message.data['notificationTitle']?.toString() ??
          message.data['title']?.toString();
      final body =
          message.notification?.body ??
          message.data['notificationDescription']?.toString() ??
          message.data['body']?.toString() ??
          message.data['description']?.toString();
      if ((title != null && title.isNotEmpty) ||
          (body != null && body.isNotEmpty)) {
        _showLocalNotification(message, title: title, body: body);
      }
    });

    // B. When the app is in the background and the user taps on the notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👉 Notification Clicked (App was in Background)!');
      _handleNotificationClick(message.data);
    });

    // C. When the app is completely terminated and opened via a notification tap
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('👉 Notification Clicked (App was Terminated)!');
        _handleNotificationClick(message.data);
      }
    });
  }

  // Method to show local notification when the app is in the foreground
  Future<void> _showLocalNotification(
    RemoteMessage message, {
    String? title,
    String? body,
  }) async {
    if (kIsWeb || (Platform.isIOS && message.notification != null)) return;
    final notification = message.notification;
    await _localNotificationsPlugin.show(
      id: notification?.hashCode ?? message.hashCode,
      title: title ?? notification?.title,
      body: body ?? notification?.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // Handle routing when a notification is clicked
  void _handleNotificationClick(Map<String, dynamic> data) {
    NotificationRouter.open(data);
  }

  // Fetch FCM Device Token (Useful for sending to your backend)
  Future<String?> getDeviceToken() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        final apnsReady = await _waitForApnsToken();
        if (!apnsReady) {
          debugPrint(
            '⚠️ APNs token not ready yet (common on Simulator). Skipping FCM getToken().',
          );
          return null;
        }
      }

      final String? token = await _fcm.getToken();
      debugPrint("📱 FCM Device Token: $token");
      return token;
    } catch (e) {
      debugPrint("❌ Error getting FCM token: $e");
      return null;
    }
  }

  /// iOS requires an APNs token before FCM can issue a device token.
  Future<bool> _waitForApnsToken({
    int attempts = 10,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    for (var i = 0; i < attempts; i++) {
      final apnsToken = await _fcm.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return true;
      }
      await Future.delayed(delay);
    }
    return false;
  }
}
