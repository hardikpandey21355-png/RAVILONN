import 'package:flutter/material.dart';

import 'rs_kit.dart' show kRsEase;

/// Gives AppShell the route animations so ONLY the page content slides
/// (the bottom nav stays fixed), like page-slide.js.
class RsRouteAnim extends InheritedWidget {
  const RsRouteAnim({
    super.key,
    required this.animation,
    required this.secondary,
    required this.dir,
    required super.child,
  });

  final Animation<double> animation;
  final Animation<double> secondary;

  /// +1: new page comes from the right, -1: from the left
  final double dir;

  static RsRouteAnim? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<RsRouteAnim>();

  @override
  bool updateShouldNotify(RsRouteAnim old) =>
      old.animation != animation || old.secondary != secondary || old.dir != dir;
}

/// forward: new page slides in from right (24% + fade, 240ms); forward:false: from left.
/// The transition itself is drawn by AppShell, so pages must be wrapped in AppShell.
Route<T> slideRoute<T>(
  Widget page, {
  bool forward = true,
  bool standaloneTransition = false,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) => RsRouteAnim(
      animation: animation,
      secondary: secondary,
      dir: forward ? 1 : -1,
      child: page,
    ),
    transitionsBuilder: (context, animation, secondary, child) {
      if (!standaloneTransition) return child;
      final position = Tween<Offset>(
        begin: Offset(forward ? .24 : -.24, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: kRsEase));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: position, child: child),
      );
    },
  );
}