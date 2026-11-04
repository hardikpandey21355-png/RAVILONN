import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../notifications/app_notifications.dart';
import 'api_client.dart';
import 'auth_session.dart';

const String _googleWebClientId =
    '131218601501-2kufnj2hpq83f1gim4f4bodk10532203.apps.googleusercontent.com';

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, ApiClient? apiClient})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _apiClient = apiClient ?? ApiClient();

  static Future<void>? _googleInitialization;

  final FirebaseAuth _firebaseAuth;
  final ApiClient _apiClient;
  bool get currentUserExists => _firebaseAuth.currentUser != null;

  Future<void> signInWithEmail(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _finishSignIn(credential.user);
  }

  Future<void> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    late final UserCredential credential;
    var created = true;
    try {
      credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;
      created = false;
      credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
    final user = credential.user;
    if (user == null) {
      throw const ApiAuthException(message: 'Could not create your account.');
    }
    if (created) {
      try {
        await user.updateDisplayName(name);
        await user.reload();
      } catch (error) {
        await _signOutAfterFailure(error);
      }
    }
    await _finishSignIn(_firebaseAuth.currentUser);
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final credential = await _firebaseAuth.signInWithPopup(
        GoogleAuthProvider(),
      );
      await _finishSignIn(credential.user);
      return;
    }

    await _initializeGoogleSignIn();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiAuthException(
        message: 'Google sign-in did not return an ID token.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    await _finishSignIn(userCredential.user);
  }

  Future<void> restoreSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    try {
      final session = await _apiClient.getMe(user);
      session.apply();
      await AppNotifications.registerForCurrentUser();
    } on ApiAuthException catch (error) {
      if (error.statusCode == 401) {
        await signOut();
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await AppNotifications.unregisterCurrentDevice();
    await _signOutFirebaseAndProvider();
  }

  Future<void> _finishSignIn(User? user) async {
    if (user == null) {
      throw const ApiAuthException(message: 'Authentication did not complete.');
    }
    try {
      final session = await _apiClient.login(user);
      session.apply();
      await AppNotifications.registerForCurrentUser();
    } catch (error) {
      if (error is ApiAuthException && error.held) rethrow;
      await _signOutAfterFailure(error);
    }
  }

  Future<void> _signOutAfterFailure(Object originalError) async {
    try {
      await _signOutFirebaseAndProvider();
    } catch (signOutError) {
      throw StateError(
        'Sign-in failed ($originalError), and Firebase sign-out also failed '
        '($signOutError).',
      );
    }
    Error.throwWithStackTrace(originalError, StackTrace.current);
  }

  Future<void> _signOutFirebaseAndProvider() async {
    final hadGoogleProvider =
        _firebaseAuth.currentUser?.providerData.any(
          (provider) => provider.providerId == GoogleAuthProvider.PROVIDER_ID,
        ) ??
        false;
    await _firebaseAuth.signOut();
    AuthSession.clear();
    if (!kIsWeb && hadGoogleProvider) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Google sign-out failed (${error.runtimeType}).');
      }
    }
  }

  static Future<void> _initializeGoogleSignIn() async {
    final initialization = _googleInitialization ??= GoogleSignIn.instance
        .initialize(serverClientId: _googleWebClientId);
    try {
      await initialization;
    } catch (_) {
      if (identical(_googleInitialization, initialization)) {
        _googleInitialization = null;
      }
      rethrow;
    }
  }
}
