import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/api_client.dart';
import '../auth/auth_session.dart';
import 'app_popup_dialog.dart';

class AppPopupService {
  AppPopupService({
    ApiClient? apiClient,
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _apiClient = apiClient ?? ApiClient(),
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  final ApiClient _apiClient;
  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<void> checkOnOpen(BuildContext context) async {
    try {
      final response = await _apiClient.getJson('/api/app-popup');
      if (response['enabled'] != true) return;

      final title = response['title'];
      final message = response['message'];
      final showMode = response['showMode'];
      if (title is! String ||
          title.trim().isEmpty ||
          message is! String ||
          message.trim().isEmpty ||
          (showMode != 'once' && showMode != 'every_open')) {
        throw const FormatException('App pop-up settings are invalid.');
      }

      final userId = AuthSession.userId.value;
      if (userId.isEmpty) {
        throw StateError(
          'Cannot track the pop-up without an authenticated user.',
        );
      }
      final preferences = await _preferencesProvider();
      final seenKey = 'rivalon_app_popup_seen_v1_$userId';
      final suppressedKey = 'rivalon_app_popup_suppressed_v1_$userId';
      if (preferences.getBool(suppressedKey) == true ||
          (showMode == 'once' && preferences.getBool(seenKey) == true)) {
        return;
      }
      if (!context.mounted) return;

      final stopShowing = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => AppPopupDialog(
          title: title,
          message: message,
          allowOptOut: showMode == 'every_open',
        ),
      );

      if (showMode == 'every_open' && stopShowing == true) {
        if (!await preferences.setBool(suppressedKey, true)) {
          throw StateError('Could not save the pop-up display preference.');
        }
      } else if (showMode == 'once' &&
          !await preferences.setBool(seenKey, true)) {
        throw StateError('Could not save the pop-up display state.');
      }
    } catch (error) {
      debugPrint('App pop-up check failed (${error.runtimeType}).');
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load the app message. Please try again later.',
          ),
        ),
      );
    }
  }
}
