import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/profile/data/profile_repository.dart';

class AppNotifications {
  AppNotifications._();

  static const _channel = AndroidNotificationChannel(
    'rivalon_updates',
    'RIVALON updates',
    description: 'Account, wallet and tournament updates.',
    importance: Importance.high,
  );
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;
  static String? _pendingLink;
  static bool _registrationListening = false;

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleLocalTap,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleMessageTap(initialMessage);
    _listenForRegistration();
  }

  static Future<void> registerForCurrentUser() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      _listenForRegistration();
      await _messaging.register();
    } catch (error) {
      debugPrint('Notifications: device registration failed: $error');
    }
  }

  static void _listenForRegistration() {
    if (_registrationListening) return;
    _registrationListening = true;
    _messaging.onRegistered.listen((fid) {
      if (FirebaseAuth.instance.currentUser == null) return;
      unawaited(_saveRegistrationId(fid));
    });
  }

  static Future<void> _saveRegistrationId(String fid) async {
    try {
      await ProfileRepository().saveFcmToken(fid);
    } catch (error) {
      debugPrint(
        'Notifications: registration update failed (${error.runtimeType}).',
      );
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await ProfileRepository().removeFcmToken();
    } catch (error) {
      debugPrint(
        'Notifications: device unregistration failed (${error.runtimeType}).',
      );
    }
  }

  static Future<void> consumePendingTap() async {
    final link = _pendingLink;
    if (link == null || FirebaseAuth.instance.currentUser == null) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    _pendingLink = null;
    await navigator.pushNamed(link);
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if (title is! String || body is! String) return;
    unawaited(
      _local
          .show(
            id: message.hashCode,
            title: title,
            body: body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: const DarwinNotificationDetails(),
            ),
            payload: jsonEncode({'link': message.data['link']}),
          )
          .catchError((Object error) {
            debugPrint(
              'Notifications: foreground display failed (${error.runtimeType}).',
            );
          }),
    );
  }

  static void _handleMessageTap(RemoteMessage message) {
    _openLink(message.data['link']);
  }

  static void _handleLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map) _openLink(data['link']);
    } on FormatException {
      debugPrint('Notifications: ignored an invalid notification payload.');
    }
  }

  static void _openLink(Object? value) {
    if (value is! String || !_isAllowedLink(value)) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _pendingLink = value;
      return;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingLink = value;
      return;
    }
    unawaited(navigator.pushNamed(value));
  }

  static bool _isAllowedLink(String link) {
    if (link == '/' ||
        link == '/wallet' ||
        link == '/profile' ||
        link == '/matches' ||
        link == '/tournaments' ||
        link == '/notifications') {
      return true;
    }
    final uri = Uri.tryParse(link);
    return uri != null &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'tournament' &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }
}
