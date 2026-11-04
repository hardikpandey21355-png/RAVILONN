import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/api_client.dart';
import '../../../core/auth/auth_session.dart';
import 'profile_mock.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<GameIdResult> saveGameId(String ign, String uid) async {
    final response = await _apiClient.postJson(
      '/api/profile/game-id',
      body: {'ign': ign, 'uid': uid},
    );
    _requireOk(response);
    final savedIgn = response['ign'] is String
        ? response['ign'] as String
        : ign;
    final savedUid = response['uid'] is String
        ? response['uid'] as String
        : uid;
    AuthSession.ign.value = savedIgn;
    AuthSession.gameUid.value = savedUid;
    AuthSession.gameOk.value = true;
    return GameIdResult(ok: true, ign: savedIgn, uid: savedUid);
  }

  Future<UpiResult> saveUpi(String upi, XFile? shot) async {
    final form = FormData();
    form.fields.add(MapEntry('upi', upi));
    if (shot != null) {
      final extension = shot.name.split('.').last.toLowerCase();
      const contentTypes = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
      };
      final contentType = contentTypes[extension];
      if (contentType == null) {
        throw const ApiAuthException(
          message: 'Screenshot must be a JPG, PNG, or WebP image.',
        );
      }
      final bytes = await shot.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw const ApiAuthException(
          message: 'Screenshot must be 5 MB or smaller.',
        );
      }
      form.files.add(
        MapEntry(
          'shot',
          MultipartFile.fromBytes(
            bytes,
            filename: shot.name,
            contentType: DioMediaType.parse(contentType),
          ),
        ),
      );
    }

    final response = await _apiClient.postForm('/api/profile/upi', body: form);
    _requireOk(response);
    final savedUpi = response['upi'] is String
        ? response['upi'] as String
        : upi;
    final hasShot = response['has_shot'] == true;
    AuthSession.upi.value = savedUpi;
    AuthSession.hasUpi.value = savedUpi.isNotEmpty;
    AuthSession.hasUpiShot.value = hasShot;
    return UpiResult(ok: true, upi: savedUpi, hasShot: hasShot);
  }

  Future<void> saveNotifSettings({
    required bool push,
    required bool reminders,
    required bool results,
  }) async {
    final response = await _apiClient.postJson(
      '/api/profile/notif-settings',
      body: {'push': push, 'reminders': reminders, 'results': results},
    );
    _requireOk(response);
    AuthSession.pushNotifications.value = push;
    AuthSession.matchReminders.value = reminders;
    AuthSession.resultAlerts.value = results;
  }

  Future<Map<String, bool>> loadNotifSettings() async {
    final response = await _apiClient.getJson('/api/me');
    _requireOk(response);
    AuthSessionData.fromJson(response).apply();
    return {
      'push': AuthSession.pushNotifications.value,
      'reminders': AuthSession.matchReminders.value,
      'results': AuthSession.resultAlerts.value,
    };
  }

  Future<ProfileStats> loadStats() async {
    final response = await _apiClient.getJson('/api/profile/stats');
    _requireOk(response);
    return ProfileStats.fromJson(response);
  }

  Future<void> saveFcmToken(String token) async {
    final response = await _apiClient.postJson(
      '/api/profile/fcm-token',
      body: {'token': token},
    );
    _requireOk(response);
  }

  Future<void> removeFcmToken() async {
    final response = await _apiClient.postJson(
      '/api/profile/fcm-token',
      body: const {'remove': true},
    );
    _requireOk(response);
  }

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 30}) async {
    final response = await _apiClient.getJson(
      '/api/notifications',
      queryParameters: {'limit': limit},
    );
    _requireOk(response);
    final notifications = response['notifications'];
    if (notifications is! List) {
      throw const ApiAuthException(
        message: 'The server returned invalid notifications.',
      );
    }
    return notifications
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> readAllNotifications() async {
    final response = await _apiClient.postJson(
      '/api/notifications/read-all',
      body: const {},
    );
    _requireOk(response);
  }

  void _requireOk(Map<String, dynamic> response) {
    if (response['ok'] == true) return;
    final error = response['error'];
    throw ApiAuthException(
      message: error is String && error.trim().isNotEmpty
          ? error.trim()
          : 'Something went wrong. Try again.',
    );
  }
}

class ProfileStats {
  const ProfileStats({
    required this.matches,
    required this.wins,
    required this.kills,
    required this.earned,
  });

  final int matches;
  final int wins;
  final int kills;
  final int earned;

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    final values = <String, int>{};
    for (final field in const ['matches', 'wins', 'kills', 'earned']) {
      final value = json[field];
      if (value is! int || value < 0) {
        throw const ApiAuthException(
          message: 'The server returned invalid profile stats.',
        );
      }
      values[field] = value;
    }
    return ProfileStats(
      matches: values['matches']!,
      wins: values['wins']!,
      kills: values['kills']!,
      earned: values['earned']!,
    );
  }
}
