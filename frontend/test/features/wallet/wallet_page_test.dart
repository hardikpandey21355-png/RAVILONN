import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/core/rs_kit.dart';
import 'package:ravilon/core/widgets/wallet_chip.dart';
import 'package:ravilon/features/wallet/data/wallet_mock.dart';
import 'package:ravilon/features/wallet/presentation/wallet_page.dart';

void main() {
  setUp(() {
    MockData.walletBalance.value = WalletMock.initialState.total;
    MockData.upi.value = '';
    MockData.hasUpi.value = false;
    WalletMock.currentState = WalletMock.initialState;
  });

  testWidgets('wallet content fills the phone viewport width', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WalletPage(
          walletChip: WalletChip(balanceListenable: MockData.walletBalance),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(BalanceCard)).width, greaterThan(350));
  });

  testWidgets('wallet chip reflects changes to the shared balance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WalletPage(
          walletChip: WalletChip(balanceListenable: MockData.walletBalance),
          onTotalChanged: (total) => MockData.walletBalance.value = total,
        ),
      ),
    );
    await tester.pumpAndSettle();

    MockData.walletBalance.value = 1300;
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(WalletChip),
        matching: find.text('₹ 1,300'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('initial balance callback does not notify during build', (
    tester,
  ) async {
    final balance = ValueNotifier<int>(0);
    addTearDown(balance.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: balance,
          builder: (context, _, _) => WalletPage(
            walletChip: WalletChip(balanceListenable: balance),
            onTotalChanged: (total) => balance.value = total,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('withdrawal panel reflects shared profile UPI changes', (
    tester,
  ) async {
    MockData.upi.value = '';
    MockData.hasUpi.value = false;

    await tester.pumpWidget(
      MaterialApp(
        home: WalletPage(
          walletChip: WalletChip(balanceListenable: MockData.walletBalance),
        ),
      ),
    );
    await tester.pumpAndSettle();

    MockData.upi.value = 'player@upi';
    MockData.hasUpi.value = true;
    await tester.pump();
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();

    expect(find.text('player@upi'), findsOneWidget);
    expect(find.text('Add your UPI ID to withdraw'), findsNothing);
  });

  testWidgets('wallet chip does not push a second wallet route', (
    tester,
  ) async {
    var pushes = 0;
    final observer = _PushObserver(() => pushes++);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/wallet',
        navigatorObservers: [observer],
        routes: {
          '/wallet': (_) => WalletPage(
            walletChip: WalletChip(balanceListenable: MockData.walletBalance),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    final walletPress = tester.widget<RsPress>(
      find.descendant(
        of: find.byType(WalletChip),
        matching: find.byType(RsPress),
      ),
    );
    expect(walletPress.onTap, isNull);
    expect(pushes, 1);
  });

  testWidgets('wallet toast stays opaque and does not animate its blur', (
    tester,
  ) async {
    final toastKey = GlobalKey<WalletToastState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.black)),
              WalletToast(key: toastKey),
            ],
          ),
        ),
      ),
    );

    toastKey.currentState!.show(
      WalletToastType.warn,
      'Check amount',
      'Please review the amount.',
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(Opacity), findsNothing);
    final surface = tester.widget<Container>(
      find.byKey(const ValueKey<String>('wallet-toast-surface')).last,
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color!.a, 1);
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.every((color) => color.a == 1), isTrue);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(BackdropFilter), findsNothing);

    toastKey.currentState!.hide();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('wallet-toast-surface')),
      findsNothing,
    );
  });

  testWidgets('add money shows payment progress while order is starting', (
    tester,
  ) async {
    final completion = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddMoneyPanel(
            notify: (_, _, _) {},
            minAdd: 5,
            maxAdd: 100,
            onSubmit: (_) => completion.future,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add ₹100'));
    await tester.pump();

    expect(find.text('Preparing secure payment...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Add ₹100'), findsOneWidget);
  });

  testWidgets('add money presets submit the selected rupee amount', (
    tester,
  ) async {
    int? submittedAmount;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddMoneyPanel(
            notify: (_, _, _) {},
            minAdd: 5,
            maxAdd: 100,
            onSubmit: (amount) async => submittedAmount = amount,
          ),
        ),
      ),
    );

    for (final amount in <int>[5, 10, 50, 100]) {
      expect(find.text('₹$amount'), findsOneWidget);
    }

    await tester.tap(find.text('₹5'));
    await tester.pump();
    await tester.tap(find.text('Add ₹5'));
    await tester.pumpAndSettle();

    expect(submittedAmount, 5);
  });

  testWidgets('off mode disables Add money and shows the pause label', (
    tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddMoneyPanel(
            notify: (_, _, _) {},
            minAdd: 5,
            maxAdd: 100,
            paymentMethod: 'off',
            onSubmit: (_) async => submitted = true,
          ),
        ),
      ),
    );

    expect(find.text('do not add money now'), findsOneWidget);
    final pauseLabel = tester.widget<Text>(find.text('do not add money now'));
    expect(pauseLabel.style?.color, const Color(0xFFFFFFFF));
    final pauseButtonOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.text('do not add money now'),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(pauseButtonOpacity.opacity, 1);
    final pauseButtonContainers = tester.widgetList<Container>(
      find.ancestor(
        of: find.text('do not add money now'),
        matching: find.byType(Container),
      ),
    );
    expect(
      pauseButtonContainers.any((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration &&
            decoration.color == const Color.fromRGBO(127, 29, 29, .72);
      }),
      isTrue,
    );
    await tester.tap(find.text('do not add money now'));
    await tester.pump();

    expect(submitted, isFalse);
    expect(find.text('Add ₹100'), findsNothing);
  });

  testWidgets('manual mode remains disabled until manual payments are built', (
    tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddMoneyPanel(
            notify: (_, _, _) {},
            minAdd: 5,
            maxAdd: 100,
            paymentMethod: 'manual',
            onSubmit: (_) async => submitted = true,
          ),
        ),
      ),
    );

    expect(find.text('To be completed'), findsOneWidget);
    await tester.tap(find.text('To be completed'));
    await tester.pump();

    expect(submitted, isFalse);
  });
}

class _PushObserver extends NavigatorObserver {
  _PushObserver(this.onPush);

  final VoidCallback onPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPush();
    super.didPush(route, previousRoute);
  }
}
