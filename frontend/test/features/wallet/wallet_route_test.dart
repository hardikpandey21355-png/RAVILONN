import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/core/rs_kit.dart';
import 'package:ravilon/core/slide_route.dart';
import 'package:ravilon/core/widgets/app_nav.dart';
import 'package:ravilon/core/widgets/app_shell.dart';
import 'package:ravilon/core/widgets/wallet_chip.dart';
import 'package:ravilon/features/wallet/presentation/wallet_page.dart';

void main() {
  testWidgets('wallet navigation renders wallet content', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = RsNavObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: Scaffold(
          body: Center(
            child: TextButton(
              child: const Text('Open wallet'),
              onPressed: () => navigatorKey.currentState!.pushNamed('/wallet'),
            ),
          ),
        ),
        builder: (context, child) => AppShell(
          navObserver: observer,
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
        onGenerateRoute: (settings) => slideRoute(
          Builder(
            builder: (context) => AppShell(
              child: WalletPage(
                walletChip: WalletChip(
                  balanceListenable: MockData.walletBalance,
                ),
                bottomInset: const EdgeInsets.only(bottom: 100),
              ),
            ),
          ),
          settings: settings,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open wallet'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RsIn), findsNWidgets(4));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Add • Play • Withdraw'), findsOneWidget);
  });
}
