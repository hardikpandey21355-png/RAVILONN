import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/app_update/app_popup_dialog.dart';
import 'package:ravilon/core/app_update/app_popup_service.dart';
import 'package:ravilon/core/auth/api_client.dart';
import 'package:ravilon/core/auth/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PopupSettingsApi extends ApiClient {
  PopupSettingsApi(this.showMode);

  final String showMode;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    expect(path, '/api/app-popup');
    return {
      'enabled': true,
      'title': 'Ready for your next match?',
      'message': 'Join a tournament.',
      'showMode': showMode,
    };
  }
}

Future<BuildContext> _mountHome(WidgetTester tester) async {
  late BuildContext homeContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          homeContext = context;
          return const Scaffold(body: Text('Home'));
        },
      ),
    ),
  );
  return homeContext;
}

Future<void> _dismissPopup(
  WidgetTester tester, {
  String button = 'Close',
}) async {
  expect(find.byType(AppPopupDialog), findsOneWidget);
  await tester.tap(find.text(button));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.userId.value = 'popup-test-user';
  });

  testWidgets('once mode displays once per account on this device', (
    tester,
  ) async {
    final context = await _mountHome(tester);
    final service = AppPopupService(apiClient: PopupSettingsApi('once'));

    final firstCheck = service.checkOnOpen(context);
    await tester.pump();
    await _dismissPopup(tester);
    await firstCheck;

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool('rivalon_app_popup_seen_v1_popup-test-user'),
      isTrue,
    );

    await service.checkOnOpen(context);
    await tester.pump();
    expect(find.byType(AppPopupDialog), findsNothing);
  });

  testWidgets('every-open mode shows again after the popup is dismissed', (
    tester,
  ) async {
    final context = await _mountHome(tester);
    final service = AppPopupService(apiClient: PopupSettingsApi('every_open'));

    final firstCheck = service.checkOnOpen(context);
    await tester.pump();
    await _dismissPopup(tester, button: 'Not now');
    await firstCheck;

    final secondCheck = service.checkOnOpen(context);
    await tester.pump();
    await _dismissPopup(tester, button: 'Not now');
    await secondCheck;
  });

  testWidgets('players can suppress recurring popups on this device', (
    tester,
  ) async {
    final context = await _mountHome(tester);
    final service = AppPopupService(apiClient: PopupSettingsApi('every_open'));

    final firstCheck = service.checkOnOpen(context);
    await tester.pump();
    await _dismissPopup(tester, button: "Don't show again on this device");
    await firstCheck;

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool('rivalon_app_popup_suppressed_v1_popup-test-user'),
      isTrue,
    );

    await service.checkOnOpen(context);
    await tester.pump();
    expect(find.byType(AppPopupDialog), findsNothing);
  });
}
