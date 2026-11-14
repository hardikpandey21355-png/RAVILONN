import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/api_client.dart';
import 'app_popup_service.dart';

const int currentAppBuildNumber = 9;

class AppUpdateService {
  AppUpdateService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> checkOnOpen(BuildContext context) async {
    await _checkForUpdate(context);
    if (!context.mounted) return;
    await AppPopupService(apiClient: _apiClient).checkOnOpen(context);
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    try {
      final response = await _apiClient.getJson('/api/app-update');
      final latestBuild = _integer(response['latestBuildNumber']);
      final versionName = response['latestVersionName'];
      final message = response['message'];
      final downloadUrl = response['downloadUrl'];
      final forceUpdate = response['forceUpdate'] == true;
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
        builder: (context) => PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            title: Text(
              forceUpdate
                  ? 'Update required'
                  : 'Ravilon update $versionName is ready',
            ),
            content: Text(message),
            actions: forceUpdate
                ? [
                    FilledButton(
                      onPressed: () async {
                        try {
                          final launched = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (launched || !context.mounted) return;
                          _showMessage(
                            context,
                            'Could not open the APK download page.',
                          );
                        } catch (error) {
                          debugPrint(
                            'App update link failed (${error.runtimeType}).',
                          );
                          if (context.mounted) {
                            _showMessage(
                              context,
                              'Could not open the APK download page.',
                            );
                          }
                        }
                      },
                      child: const Text('Update now'),
                    ),
                  ]
                : [
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
        ),
        barrierDismissible: !forceUpdate,
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

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
    }
    return 0;
  }
}
