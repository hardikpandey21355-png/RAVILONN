// Models + mock values for the Profile UI. UI-only: no backend, no Firebase.
import 'dart:async';

import 'package:image_picker/image_picker.dart';

class GameIdState {
  const GameIdState({this.ign = '', this.uid = '', this.saved = false});
  final String ign;
  final String uid;
  final bool saved;
}

class UpiState {
  const UpiState({this.upi = '', this.hasShot = false});
  final String upi;
  final bool hasShot;
}

class GameIdResult {
  const GameIdResult({
    required this.ok,
    this.error,
    this.ign = '',
    this.uid = '',
  });
  final bool ok;
  final String? error;
  final String ign;
  final String uid;
}

class UpiResult {
  const UpiResult({
    required this.ok,
    this.error,
    this.upi = '',
    this.hasShot = false,
  });
  final bool ok;
  final String? error;
  final String upi;
  final bool hasShot;
}

// ---- mock values ----
const String kMockUserName = 'Player';
const String kMockUserEmail = 'player@example.com';
const String? kMockPictureUrl = null;
const GameIdState kMockGame = GameIdState(ign: '', uid: '', saved: false);
const UpiState kMockUpi = UpiState(upi: '', hasShot: false);

// ---- mock actions (used when the page callbacks are null) ----
Future<GameIdResult> mockSaveGameId(String ign, String uid) async {
  await Future<void>.delayed(const Duration(milliseconds: 700));
  return GameIdResult(ok: true, ign: ign, uid: uid);
}

bool _mockHasShot = false;

Future<UpiResult> mockSaveUpi(String upi, XFile? shot) async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  _mockHasShot = _mockHasShot || shot != null;
  return UpiResult(ok: true, upi: upi, hasShot: _mockHasShot);
}

Future<XFile?> mockPickScreenshot() async => null;
