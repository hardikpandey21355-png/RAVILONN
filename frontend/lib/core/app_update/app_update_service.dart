import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/api_client.dart';
import '../auth/auth_session.dart';

const int currentAppBuildNumber = 3;

class AppUpdateService {
  AppUpdateService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> checkOnOpen(BuildContext context) async {
    await _claimBonus(context);
    if (!context.mounted) return;
    await _checkForUpdate(context);
  }

  Future<void> _claimBonus(BuildContext context) async {
    try {
      final response = await _apiClient.postJson(
        '/api/app-update/claim',
        body: {'buildNumber': currentAppBuildNumber},
      );
      final wallet = response['wallet'];
      if (wallet is Map) {
        AuthSession.deposited.value = _integer(wallet['deposited']);
        AuthSession.bonus.value = _integer(wallet['bonus']);
        AuthSession.winnings.value = _integer(wallet['winnings']);
        AuthSession.walletTotal.value = _integer(wallet['total']);
      }
      if (response['credited'] == true) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('₹10 bonus added'),
            content: const Text(
              'Your one-time app update bonus is now in your deposit balance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      } else if (_integer(response['migratedToDeposit']) > 0 &&
          context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bonus moved to deposit balance'),
            content: Text(
              '₹${_integer(response['migratedToDeposit'])} from your existing '
              'update bonus is now in your deposit balance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      debugPrint(
        'App update bonus could not be claimed (${error.runtimeType}).',
      );
      if (!context.mounted) return;
      _showMessage(
        context,
        'Could not load your update bonus. Please try again later.',
      );
    }
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    try {
      final response = await _apiClient.getJson('/api/app-update');
      final latestBuild = _integer(response['latestBuildNumber']);
      final versionName = response['latestVersionName'];
      final message = response['message'];
      final downloadUrl = response['downloadUrl'];
      if (response['enabled'] != true ||
          latestBuild <= currentAppBuildNumber ||
          versionName is! String ||
          message is! String ||
          downloadUrl is! String) {
        return;
      }

      final uri = Uri.tryParse(downloadUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Update download URL is invalid.');
      }

      if (!context.mounted) return;
      final shouldUpdate = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: Text('Ravilon update $versionName is ready'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Update APK'),
            ),
          ],
        ),
      );
      if (shouldUpdate == true) {
        if (!context.mounted) return;
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          if (!context.mounted) return;
          _showMessage(context, 'Could not open the APK download page.');
        }
      }
    } catch (error) {
      debugPrint('App update check failed (${error.runtimeType}).');
      if (!context.mounted) return;
      _showMessage(
        context,
        'Could not check for app updates. Please try again later.',
      );
    }
  }

  int _integer(Object? value) => value is int && value >= 0 ? value : 0;

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }
}
