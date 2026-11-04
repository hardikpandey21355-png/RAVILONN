import 'package:flutter/material.dart';

import '../rs_kit.dart';
import '../slide_route.dart';
import 'app_nav.dart';

/// Wrap navigable pages to animate page content independently of the app nav.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    this.activeIndex,
    this.navObserver,
    this.navigatorKey,
    this.fadeTransition = true,
  });
  final Widget child;
  final int? activeIndex;
  final RsNavObserver? navObserver;
  final GlobalKey<NavigatorState>? navigatorKey;
  final bool fadeTransition;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  RsRouteAnim? _routeAnim;
  int _revealGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = RsRouteAnim.maybeOf(context);
    if (identical(next, _routeAnim)) return;
    _routeAnim?.secondary.removeStatusListener(_onSecondaryStatusChanged);
    _routeAnim = next;
    _routeAnim?.secondary.addStatusListener(_onSecondaryStatusChanged);
  }

  void _onSecondaryStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.reverse && mounted) {
      setState(() => _revealGeneration++);
    }
  }

  @override
  void dispose() {
    _routeAnim?.secondary.removeStatusListener(_onSecondaryStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.activeIndex == null ||
          (widget.activeIndex! >= 0 && widget.activeIndex! <= 4),
    );
    final observer = widget.navObserver;
    final navigatorKey = widget.navigatorKey;
    if (observer != null && navigatorKey != null) {
      final bottom = 8 + MediaQuery.paddingOf(context).bottom;
      return Stack(
        children: [
          Positioned.fill(child: widget.child),
          ValueListenableBuilder<bool>(
            valueListenable: observer.visible,
            builder: (context, visible, _) => Positioned(
              left: 10,
              right: 10,
              bottom: bottom,
              child: IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: ValueListenableBuilder<int>(
                        valueListenable: observer.active,
                        builder: (context, active, _) =>
                            AppNav(active: active, navigatorKey: navigatorKey),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final ra = _routeAnim;

    if (ra == null || rsReduce(context)) {
      return Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(children: [Positioned.fill(child: widget.child)]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: Listenable.merge([ra.animation, ra.secondary]),
        builder: (context, child) {
          final revealingPreviousPage =
              ra.secondary.status == AnimationStatus.reverse;
          final progress = revealingPreviousPage
              ? 1 - ra.secondary.value
              : ra.animation.value;
          final a = kRsEase.transform(progress.clamp(0.0, 1.0));
          final y = -32 * (1 - a);

          return Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: rsK(a))),
              Positioned.fill(
                child: Opacity(
                  opacity: widget.fadeTransition ? a : 1,
                  child: Transform.translate(
                    offset: Offset(0, y),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_revealGeneration),
          child: widget.child,
        ),
      ),
    );
  }
}
