import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/auth/api_client.dart';

class _FakeUser implements User {
  bool forceRefreshed = false;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) {
      forceRefreshed = true;
      return 'fresh-token';
    }
    return 'stale-token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements FirebaseAuth {
  _FakeAuth(this.user);

  final User user;

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('refreshes Firebase token once and retries a 401 request', () async {
    final user = _FakeUser();
    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          if (options.headers['Authorization'] == 'Bearer stale-token') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Object?>(
                  requestOptions: options,
                  statusCode: 401,
                  data: {
                    'ok': false,
                    'error': 'Firebase ID token is invalid or expired.',
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'ok': true},
            ),
          );
        },
      ),
    );
    final client = ApiClient(dio: dio, auth: _FakeAuth(user));

    final response = await client.postJson(
      '/api/profile/notif-settings',
      body: const {'push': true, 'reminders': true, 'results': true},
    );

    expect(response['ok'], isTrue);
    expect(requestCount, 2);
    expect(user.forceRefreshed, isTrue);
  });
}
