import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'api_client.dart';

/// Push messages that arrive in the background are shown by the system; this
/// handler only has to exist (it runs in its own isolate).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
}

/// Firebase in one place:
/// * Analytics: screens and key actions (sign-in, offers, bookings, tickets).
/// * Crashlytics: uncaught errors on Android and iOS.
/// * Cloud Messaging: push notifications; the device token is sent to the API
///   (POST /auth/push-token) so the server can notify this phone.
///
/// Everything is optional: before `flutterfire configure` is run, [enabled]
/// stays false and every call here does nothing.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool enabled = false;
  String? pushToken;
  FirebaseAnalytics? _analytics;

  /// Shows in-app banners for push messages that arrive while the app is open.
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Called when a push notification is tapped (with its data payload).
  void Function(Map<String, dynamic> data)? onOpenNotification;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      enabled = true;
    } catch (e) {
      debugPrint('[firebase] off: $e');
      return;
    }

    _analytics = FirebaseAnalytics.instance;

    if (!kIsWeb) {
      // Report crashes that Flutter catches and those it does not.
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    }

    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text([n.title, n.body].whereType<String>().join(' · ')),
        action: SnackBarAction(label: 'Open', onPressed: () => onOpenNotification?.call(m.data)),
      ));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpenNotification?.call(m.data));
  }

  /// Asks for permission to send notifications and registers this device with
  /// the API. Called after sign-in.
  Future<void> registerForPush() async {
    if (!enabled) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // ignore: deprecated_member_use
      pushToken = await FirebaseMessaging.instance.getToken();
      if (pushToken != null) {
        await Api.instance.post('/auth/push-token', {'token': pushToken, 'platform': defaultTargetPlatform.name});
      }
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        pushToken = t;
        Api.instance.post('/auth/push-token', {'token': t, 'platform': defaultTargetPlatform.name}).catchError((_) => <String, dynamic>{});
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) onOpenNotification?.call(initial.data);
    } catch (e) {
      debugPrint('[firebase] push not available: $e');
    }
  }

  /// Removes this device from the API so a signed-out phone gets no pushes.
  Future<void> unregisterPush() async {
    if (!enabled || pushToken == null) return;
    try {
      await Api.instance.dio.delete('/auth/push-token', data: {'token': pushToken});
    } catch (_) {}
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!enabled) return;
    try {
      await _analytics?.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  Future<void> setUser(String? id, String? role) async {
    if (!enabled) return;
    try {
      await _analytics?.setUserId(id: id);
      if (role != null) await _analytics?.setUserProperty(name: 'role', value: role);
      if (!kIsWeb) await FirebaseCrashlytics.instance.setUserIdentifier(id ?? '');
    } catch (_) {}
  }

  Future<void> logScreen(String name) async {
    if (!enabled) return;
    try {
      await _analytics?.logScreenView(screenName: name);
    } catch (_) {}
  }
}
