import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/env.dart';
import 'auth_session.dart';

class ApiAuthException implements Exception {
  const ApiAuthException({
    required this.message,
    this.statusCode,
    this.held = false,
  });

  final String message;
  final int? statusCode;
  final bool held;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({Dio? dio, FirebaseAuth? auth})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 12),
              headers: const {'Content-Type': 'application/json'},
            ),
          ),
      firebaseAuth = auth;

  final Dio _dio;
  final FirebaseAuth? firebaseAuth;

  Future<AuthSessionData> login(User user) async {
    var token = await _freshToken(user, forceRefresh: true);
    final response = await _retryUnauthorized(
      () => _dio.post<Object?>(
        '/api/auth/login',
        data: {'idToken': token},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ),
      () async {
        token = await _freshToken(user, forceRefresh: true);
      },
    );
    return _sessionFromResponse(response);
  }

  Future<AuthSessionData> getMe(User user) async {
    var token = await _freshToken(user, forceRefresh: true);
    final response = await _retryUnauthorized(
      () => _dio.get<Object?>(
        '/api/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ),
      () async {
        token = await _freshToken(user, forceRefresh: true);
      },
    );
    return _sessionFromResponse(response);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    var token = await _currentToken();
    return _retryUnauthorized(
      () => _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ),
      () async {
        token = await _currentToken(forceRefresh: true);
      },
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    var token = await _currentToken();
    return _retryUnauthorized(
      () => _dio.post<Object?>(
        path,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      ),
      () async {
        token = await _currentToken(forceRefresh: true);
      },
    );
  }

  Future<Map<String, dynamic>> postForm(
    String path, {
    required FormData body,
  }) async {
    final token = await _currentToken();
    return _request(
      () => _dio.post<Object?>(
        path,
        data: body,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: Headers.multipartFormDataContentType,
        ),
      ),
    );
  }

  Future<String> _currentToken({bool forceRefresh = false}) async {
    final user = (firebaseAuth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw const ApiAuthException(
        message: 'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    return _freshToken(user, forceRefresh: forceRefresh);
  }

  Future<String> _freshToken(User user, {bool forceRefresh = false}) async {
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw const ApiAuthException(message: 'Could not refresh your session.');
    }
    return token;
  }

  Future<Map<String, dynamic>> _retryUnauthorized(
    Future<Response<Object?>> Function() request,
    Future<void> Function() refreshToken,
  ) async {
    try {
      return await _request(request);
    } on ApiAuthException catch (error) {
      if (error.statusCode != 401) rethrow;
      await refreshToken();
      return _request(request);
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      final response = await request();
      final body = _asMap(response.data);
      _updateMaintenance(body);
      return body;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final body = _asMap(error.response?.data);
      _updateMaintenance(body);
      if (statusCode == 403 && body['held'] == true) {
        AuthSession.accountHeld.value = true;
        throw const ApiAuthException(
          message: 'Account on hold',
          statusCode: 403,
          held: true,
        );
      }
      if (statusCode == 401) {
        throw ApiAuthException(
          message: _errorMessage(body, fallback: 'Your session has expired.'),
          statusCode: 401,
        );
      }
      if (statusCode != null) {
        throw ApiAuthException(
          message: _errorMessage(
            body,
            fallback: 'Something went wrong. Try again.',
          ),
          statusCode: statusCode,
        );
      }
      if (_isNetworkFailure(error)) {
        throw const ApiAuthException(
          message:
              "Can't reach the RIVALON server. Check that the backend is "
              'running and try again.',
        );
      }
      throw const ApiAuthException(message: 'Something went wrong. Try again.');
    }
  }

  AuthSessionData _sessionFromResponse(Map<String, dynamic> response) {
    if (response['ok'] != true) {
      if (response['held'] == true) {
        AuthSession.accountHeld.value = true;
        throw const ApiAuthException(message: 'Account on hold', held: true);
      }
      throw ApiAuthException(
        message: _errorMessage(
          response,
          fallback: 'Could not sign in right now. Please try again.',
        ),
      );
    }
    if (response['user'] is! Map || response['wallet'] is! Map) {
      throw const ApiAuthException(
        message: 'The server returned an invalid session. Please try again.',
      );
    }
    final user = _asMap(response['user']);
    if (user['uid'] is! String || (user['uid'] as String).isEmpty) {
      throw const ApiAuthException(
        message: 'The server returned an invalid session. Please try again.',
      );
    }
    return AuthSessionData.fromJson(response);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  String _errorMessage(Map<String, dynamic> body, {required String fallback}) {
    final message = body['error'];
    return message is String && message.trim().isNotEmpty
        ? message.trim()
        : fallback;
  }

  void _updateMaintenance(Map<String, dynamic> body) {
    final value = body['maintenance'];
    if (value is Map) {
      final status = Map<String, dynamic>.from(value);
      AuthSession.maintenanceOn.value = status['on'] == true;
      final message = status['message'];
      final eta = status['eta'];
      AuthSession.maintenanceMessage.value =
          message is String && message.isNotEmpty
          ? message
          : 'We will be back shortly.';
      AuthSession.maintenanceEta.value = eta is String ? eta : '';
    } else if (value == true) {
      AuthSession.maintenanceOn.value = true;
      final message = body['message'];
      final eta = body['eta'];
      AuthSession.maintenanceMessage.value =
          message is String && message.isNotEmpty
          ? message
          : 'We will be back shortly.';
      AuthSession.maintenanceEta.value = eta is String ? eta : '';
    }
  }

  bool _isNetworkFailure(DioException error) =>
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError;
}
