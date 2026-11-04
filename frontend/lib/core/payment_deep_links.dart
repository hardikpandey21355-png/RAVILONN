import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'notifications/app_notifications.dart';

class PaymentDeepLinks {
  PaymentDeepLinks._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;
  static Uri? _pendingLink;
  static String? _lastHandledLink;

  static Future<void> initialize() async {
    _subscription ??= _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'payment deep links',
          ),
        );
      },
    );
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) _handleUri(initialLink);
  }

  static void _handleUri(Uri uri) {
    if (uri.scheme != 'rivalon' ||
        uri.host != 'wallet' ||
        uri.path.isNotEmpty) {
      return;
    }
    if (_lastHandledLink == uri.toString()) return;
    _lastHandledLink = uri.toString();
    _pendingLink = uri;
    unawaited(consumePending());
  }

  static Future<void> consumePending() async {
    if (_pendingLink == null || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    final navigator = AppNotifications.navigatorKey.currentState;
    if (navigator == null) return;
    final link = _pendingLink!;
    _pendingLink = null;
    final pay = link.queryParameters['pay'];
    final status = const {'paid', 'pending', 'failed'}.contains(pay)
        ? pay
        : null;
    navigator.pushNamedAndRemoveUntil('/', (route) => false);
    navigator.pushNamed('/wallet', arguments: status);
  }
}
