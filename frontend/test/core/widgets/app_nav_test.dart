import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/rs_kit.dart';
import 'package:ravilon/core/widgets/app_nav.dart';

void main() {
  testWidgets('tournament tab navigates from the builder overlay', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = RsNavObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Center(child: Text('Home page'))),
        routes: {
          '/tournaments': (_) =>
              const Scaffold(body: Center(child: Text('Tournament page'))),
        },
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<int>(
                valueListenable: observer.active,
                builder: (context, active, _) =>
                    AppNav(active: active, navigatorKey: navigatorKey),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Tournaments'));
    await tester.pumpAndSettle();

    expect(find.text('Tournament page'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Tournaments')).style?.decoration,
      TextDecoration.none,
    );
  });

  testWidgets('home tab returns from wallet when home is underneath it', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = RsNavObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        initialRoute: '/',
        routes: {
          '/': (_) => const Scaffold(body: Center(child: Text('Home page'))),
          '/wallet': (_) =>
              const Scaffold(body: Center(child: Text('Wallet page'))),
        },
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<int>(
                valueListenable: observer.active,
                builder: (context, active, _) =>
                    AppNav(active: active, navigatorKey: navigatorKey),
              ),
            ),
          ],
        ),
      ),
    );

    navigatorKey.currentState!.pushNamed('/wallet');
    await tester.pumpAndSettle();
    expect(find.text('Wallet page'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home page'), findsOneWidget);
    expect(observer.active.value, 0);
  });

  testWidgets('non-tab routes preserve the current selected navigation tab', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = RsNavObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        initialRoute: '/profile',
        navigatorObservers: [observer],
        routes: {
          '/profile': (_) => const Scaffold(body: Text('Profile page')),
          '/dialog': (_) => const Scaffold(body: Text('Dialog page')),
        },
      ),
    );
    expect(observer.active.value, 4);

    navigatorKey.currentState!.pushNamed('/dialog');
    await tester.pumpAndSettle();
    expect(observer.active.value, 4);
    expect(observer.visible.value, isFalse);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.active.value, 4);
    expect(observer.visible.value, isTrue);
  });

  testWidgets('selected navigation tab moves smoothly as widths change', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = RsNavObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        initialRoute: '/',
        navigatorObservers: [observer],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Page')),
        ),
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<int>(
                valueListenable: observer.active,
                builder: (context, active, _) =>
                    AppNav(active: active, navigatorKey: navigatorKey),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final homeWidth = tester
        .getSize(find.byKey(const ValueKey('app-nav-tab-0')))
        .width;
    final profileWidth = tester
        .getSize(find.byKey(const ValueKey('app-nav-tab-4')))
        .width;
    final homeIndicator = tester.getRect(
      find.byKey(const ValueKey('app-nav-active-indicator')),
    );
    expect(homeWidth, greaterThan(profileWidth));

    navigatorKey.currentState!.pushNamed('/profile');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final halfwayHomeWidth = tester
        .getSize(find.byKey(const ValueKey('app-nav-tab-0')))
        .width;
    final halfwayProfileWidth = tester
        .getSize(find.byKey(const ValueKey('app-nav-tab-4')))
        .width;
    final halfwayIndicator = tester.getRect(
      find.byKey(const ValueKey('app-nav-active-indicator')),
    );
    expect(halfwayHomeWidth, lessThan(homeWidth));
    expect(halfwayHomeWidth, greaterThan(profileWidth));
    expect(halfwayProfileWidth, greaterThan(profileWidth));
    expect(halfwayProfileWidth, lessThan(homeWidth));
    expect(halfwayIndicator.center.dx, greaterThan(homeIndicator.center.dx));

    await tester.pumpAndSettle();
    final profileIndicator = tester.getRect(
      find.byKey(const ValueKey('app-nav-active-indicator')),
    );
    expect(halfwayIndicator.center.dx, lessThan(profileIndicator.center.dx));
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav-tab-4'))).width,
      greaterThan(
        tester.getSize(find.byKey(const ValueKey('app-nav-tab-0'))).width,
      ),
    );
    final homeIcon = tester.widget<RsIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('app-nav-tab-0')),
        matching: find.byType(RsIcon),
      ),
    );
    final profileIcon = tester.widget<RsIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('app-nav-tab-4')),
        matching: find.byType(RsIcon),
      ),
    );
    expect(homeIcon.size, closeTo(21, .01));
    expect(profileIcon.size, greaterThan(homeIcon.size));
  });

  testWidgets('shared button squeeze uses a short eased press animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RsPress(
              onTap: () {},
              child: SizedBox(
                width: 120,
                height: 48,
                child: Center(child: Text('Button')),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Button')),
    );
    await tester.pump();
    var scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, .95);
    expect(scale.duration, const Duration(milliseconds: 200));
    expect(scale.curve, Curves.easeInOutCubic);

    await gesture.up();
    await tester.pump();
    scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
    await tester.pumpAndSettle();
  });
}
