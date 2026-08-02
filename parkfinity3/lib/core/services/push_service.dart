import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';

/// Top-level background handler (must be a top-level or static fn).
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // Data-only work could go here. The system tray shows notification-type
  // messages automatically when the app is backgrounded, so nothing needed.
}

/// Owns FCM lifecycle: init, permission, token persistence, foreground display.
///
/// Wire order (main.dart): Firebase.initializeApp -> PushService.instance.init().
/// Call registerToken() after login and clearToken() on logout.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'parkfinity_default',
    'ParkFinity Notifications',
    description: 'Booking, payment and overstay alerts',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_ready) return;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    // Local-notifications plugin: needed to render pushes while app is foregrounded.
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await FirebaseMessaging.instance.requestPermission();

    // Foreground messages don't show automatically — render via local plugin.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    // Token rotation → keep profiles.fcm_token fresh.
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

    _ready = true;
  }

  /// Fetch the device token and store it against the signed-in profile.
  /// Safe to call multiple times; no-op if not authenticated.
  Future<void> registerToken() async {
    if (!_ready) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token}).eq('id', user.id);
    } catch (_) {
      // Non-fatal: push simply won't reach this device until next refresh.
    }
  }

  /// Clear the token on logout so a signed-out device stops receiving pushes.
  Future<void> clearToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    try {
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': null}).eq('id', user.id);
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
