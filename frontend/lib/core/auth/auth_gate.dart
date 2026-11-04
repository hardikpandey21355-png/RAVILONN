import 'package:flutter/material.dart';

import '../notifications/app_notifications.dart';
import '../payment_deep_links.dart';
import 'api_client.dart';
import 'auth_repository.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepository _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    String? errorMessage;
    try {
      await _authRepository.restoreSession();
    } on ApiAuthException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Could not restore your session. Please try again.';
    }
    if (!mounted) return;

    final hasSession = _authRepositoryCurrentUserExists();
    final route = hasSession && errorMessage == null ? '/' : '/login';
    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (settings) => false,
      arguments: errorMessage,
    );
    if (hasSession && errorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppNotifications.consumePendingTap();
        PaymentDeepLinks.consumePending();
      });
    }
  }

  bool _authRepositoryCurrentUserExists() => _authRepository.currentUserExists;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: const Center(
      child: CircularProgressIndicator(color: Color(0xFF6EE7B7)),
    ),
  );
}
