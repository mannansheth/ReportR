import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/storage/preferences_service.dart';

const _defaultChannel = AndroidNotificationChannel(
  'default',
  'Default',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService(this._preferencesService)
    : _localNotifications = FlutterLocalNotificationsPlugin();

  final PreferencesService _preferencesService;
  final FlutterLocalNotificationsPlugin _localNotifications;
  static final receivedOtp = ValueNotifier<String?>(null);

  Future<String?> refreshToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 12),
      );
      if (token != null && token.isNotEmpty) {
        await _preferencesService.setToken(token);
      }
      return token;
    } catch (error) {
      debugPrint('Push registration unavailable: ${error.runtimeType}');
      return null;
    }
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(settings: initializationSettings);

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(_defaultChannel);
    await androidNotifications?.requestNotificationsPermission();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: false,
      sound: true,
      provisional: true,
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: false,
          sound: true,
        );

    await refreshToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _preferencesService.setToken(token);
    });

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? 'OTP';
    final body = notification?.body ?? 'Your OTP has arrived';
    if (title.toLowerCase().contains('otp')) {
      receivedOtp.value = RegExp(r'\b\d{6}\b').firstMatch(body)?.group(0);
    }

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'default',
          'Default',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  }
}
