import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../rs_kit.dart';

class _Tab {
  const _Tab(this.icon, this.label, this.route);
  final String icon;
  final String label;
  final String route;
}

const List<_Tab> _tabs = [
  _Tab('home', 'Home', '/'),
  _Tab('trophy', 'Tournaments', '/tournaments'),
  _Tab('swords', 'Matches', '/matches'),
  _Tab('wallet', 'Wallet', '/wallet'),
  _Tab('user', 'Profile', '/profile'),
];

class RsNavObserver extends NavigatorObserver {
  final ValueNotifier<int> active = ValueNotifier<int>(0);
  final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    final index = switch (name) {
      '/tournaments' => 1,
      '/matches' => 2,
      '/wallet' => 3,
      '/profile' => 4,
      '/' => 0,
      _ => null,
    };
    if (index != null) active.value = index;
    visible.value =
        name == '/' ||
        name == '/tournaments' ||
        name == '/matches' ||
        name == '/wallet' ||
        name == '/profile';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _update(newRoute);
  }
}

/// Floating glass bottom nav (`common.css .nav`), hosted above the Navigator.
class AppNav extends StatefulWidget {
  const AppNav({super.key, required this.active, required this.navigatorKey});
  final int active;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AppNav> createState() => _AppNavState();
}

class _AppNavState extends State<AppNav> with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late List<double> _fromWeights;
  late double _fromIndicatorLeft;
  late double _fromIndicatorWidth;

  @override
  void initState() {
    super.initState();
    _fromWeights = _weightsFor(widget.active);
    _fromIndicatorLeft = _tabLeft(widget.active, _fromWeights);
    _fromIndicatorWidth = _tabWidth(widget.active, _fromWeights);
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(AppNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      final progress = Curves.easeInOutCubic.transform(_animation.value);
      final currentWeights = <double>[
        for (var i = 0; i < _tabs.length; i++)
          _fromWeights[i] +
              (_weight(i, oldWidget.active) - _fromWeights[i]) * progress,
      ];
      _fromIndicatorLeft =
          _fromIndicatorLeft +
          (_tabLeft(oldWidget.active, _weightsFor(oldWidget.active)) -
                  _fromIndicatorLeft) *
              progress;
      _fromIndicatorWidth =
          _fromIndicatorWidth +
          (_tabWidth(oldWidget.active, _weightsFor(oldWidget.active)) -
                  _fromIndicatorWidth) *
              progress;
      _fromWeights = currentWeights;
      final reduce = SchedulerBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;
      if (reduce) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _go(BuildContext context, int i) {
    if (i == widget.active) return;
    final nav = widget.navigatorKey.currentState;
    if (nav == null) {
      throw StateError('AppNav cannot navigate before the Navigator is ready.');
    }
    if (i == 0) {
      nav.popUntil((r) => r.isFirst || r.settings.name == '/');
    } else {
      nav.pushNamedAndRemoveUntil(
        _tabs[i].route,
        (r) => r.settings.name == '/',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RsGlass(
      radius: 26,
      blur: 4,
      base: rsC(8, 12, 11, .62),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [rsW(.1), rsW(.03)],
      ),
      border: rsW(.12),
      topLight: .14,
      shadows: [
        BoxShadow(color: rsK(.4), blurRadius: 18, offset: const Offset(0, 8)),
      ],
      padding: const EdgeInsets.all(6),
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final progress = Curves.easeInOutCubic.transform(_animation.value);
            final weights = <double>[
              for (var i = 0; i < _tabs.length; i++)
                _fromWeights[i] +
                    (_weight(i, widget.active) - _fromWeights[i]) * progress,
            ];
            final totalWeight = weights.fold<double>(0, (a, b) => a + b);
            final widths = <double>[
              for (final weight in weights)
                constraints.maxWidth * weight / totalWeight,
            ];
            final lefts = <double>[];
            var left = 0.0;
            for (final tabWidth in widths) {
              lefts.add(left);
              left += tabWidth;
            }
            final indicatorLeft =
                _fromIndicatorLeft +
                (_tabLeft(widget.active, _weightsFor(widget.active)) -
                        _fromIndicatorLeft) *
                    progress;
            final indicatorWidth =
                _fromIndicatorWidth +
                (_tabWidth(widget.active, _weightsFor(widget.active)) -
                        _fromIndicatorWidth) *
                    progress;
            return SizedBox(
              height: 54,
              child: Stack(
                children: [
                  Positioned(
                    left: indicatorLeft * constraints.maxWidth,
                    top: 0,
                    bottom: 0,
                    width: indicatorWidth * constraints.maxWidth,
                    child: RsGlass(
                      key: const ValueKey<String>('app-nav-active-indicator'),
                      radius: 20,
                      base: rsC(12, 22, 20, .45),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [rsC(110, 230, 195, .26), rsC(27, 111, 92, .2)],
                      ),
                      border: rsC(140, 240, 210, .34),
                      topLight: .26,
                    ),
                  ),
                  for (int i = 0; i < _tabs.length; i++)
                    Positioned(
                      left: lefts[i],
                      top: 0,
                      bottom: 0,
                      width: widths[i],
                      child: _TabItem(
                        tabIndex: i,
                        tab: _tabs[i],
                        on: ((weights[i] - 1) / .45).clamp(0.0, 1.0),
                        onTap: () => _go(context, i),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _tabLeft(int index, List<double> weights) {
    final sum = weights.take(index).fold<double>(0, (a, b) => a + b);
    final total = weights.fold<double>(0, (a, b) => a + b);
    return sum / total;
  }

  double _tabWidth(int index, List<double> weights) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    return weights[index] / total;
  }

  List<double> _weightsFor(int selected) => [
    for (var i = 0; i < _tabs.length; i++) _weight(i, selected),
  ];
}

double _weight(int index, int selected) => index == selected ? 1.45 : 1;

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tabIndex,
    required this.tab,
    required this.on,
    required this.onTap,
  });
  final int tabIndex;
  final _Tab tab;
  final double on; // 0..1
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(const Color(0xFFAEBBB6), kRsG2, on)!;
    final scale = .96 + .04 * on;
    return RsPress(
      scale: .94,
      duration: const Duration(milliseconds: 110),
      onTap: onTap,
      child: SizedBox(
        key: ValueKey<String>('app-nav-tab-$tabIndex'),
        height: 54,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RsIcon(tab.icon, size: 21 + 2 * on, color: color),
                    const SizedBox(height: 3),
                    Text(
                      tab.label,
                      style: rsT(
                        9.5 + .5 * on,
                        w: FontWeight.w500,
                        color: color,
                      ).copyWith(decoration: TextDecoration.none),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
