import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/features/notifications/presentation/notification_inbox_page.dart';
import 'package:ravilon/features/profile/data/profile_repository.dart';

class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository();

  int readAllCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> getNotifications({int limit = 30}) async =>
      [
        {
          'id': 'notice-1',
          'title': 'Wallet updated',
          'body': 'Your wallet has been updated with ₹100.',
          'date': '02 Nov, 08:00 PM',
          'read': false,
        },
      ];

  @override
  Future<void> readAllNotifications() async {
    readAllCalls++;
  }
}

void main() {
  testWidgets('shows inbox updates and marks them all as read', (tester) async {
    final repository = FakeProfileRepository();
    await tester.pumpWidget(
      MaterialApp(home: NotificationInboxPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wallet updated'), findsOneWidget);
    expect(
      find.text('Your wallet has been updated with ₹100.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();

    expect(repository.readAllCalls, 1);
    expect(find.byTooltip('Mark all as read'), findsOneWidget);
  });
}
