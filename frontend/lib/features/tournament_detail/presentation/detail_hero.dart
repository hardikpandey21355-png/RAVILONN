// lib/features/tournament_detail/presentation/detail_hero.dart
part of 'tournament_detail_page.dart';

class DetailHero extends StatelessWidget {
  const DetailHero({super.key, required this.t});
  final TournamentDetail t;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262626), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            t.imageUrl.isNotEmpty
                ? Image.network(
                    t.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stack) => _fallbackBanner(),
                  )
                : Image.asset(
                    'assets/images/${t.img}',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stack) {
                      debugPrint(
                        'DetailHero: could not load assets/images/${t.img} ($error)',
                      );
                      return _fallbackBanner();
                    },
                  ),
            // bottom fade: linear-gradient(0deg, #000 4%, rgba(0,0,0,.1) 72%)
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[
                      Color(0xFF000000),
                      Color(0xFF000000),
                      Color.fromRGBO(0, 0, 0, .1),
                      Color.fromRGBO(0, 0, 0, .1),
                    ],
                    stops: <double>[0, .04, .72, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: t.isLive ? const _LiveTag() : const _UpcomingTag(),
            ),
            if (t.hasPerKill)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _c(0, 0, 0, .72),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _c(255, 255, 255, .25), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _icon(_icSwords, '#fbbf24', 15),
                      const SizedBox(width: 6),
                      Text(
                        '₹${_inr(t.perKill!)} Per Kill',
                        style: _t(12, FontWeight.w600, _gold, h: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0B0B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _c(255, 255, 255, .3),
                        width: 1,
                      ),
                    ),
                    child: _icon(_icFlame, '#fb923c', 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          t.mode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(20, FontWeight.w700, _white, h: 1.15),
                        ),
                        _line(
                          24,
                          Text(
                            '${t.game} • ${t.team} | ${t.map}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(
                              12,
                              FontWeight.w400,
                              const Color(0xFFBDBDBD),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackBanner() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF0E2A26), Color(0xFF05100E)],
      ),
    ),
  );
}

/// LIVE tag with a blinking white dot (1.2s loop).
class _LiveTag extends StatefulWidget {
  const _LiveTag();

  @override
  State<_LiveTag> createState() => _LiveTagState();
}

class _LiveTagState extends State<_LiveTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _op =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: .3,
          ).chain(CurveTween(curve: Curves.ease)),
          weight: 1,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: .3,
            end: 1,
          ).chain(CurveTween(curve: Curves.ease)),
          weight: 1,
        ),
      ]).animate(_ctl);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) _ctl.repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FadeTransition(
            opacity: _op,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text('LIVE', style: _t(9, FontWeight.w600, _white, h: 1.5)),
        ],
      ),
    );
  }
}

class _UpcomingTag extends StatelessWidget {
  const _UpcomingTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _c(76, 201, 170, .25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _c(110, 230, 195, .5), width: 1),
      ),
      child: Text(
        'UPCOMING',
        style: _t(9, FontWeight.w600, const Color(0xFFEAFFF7), h: 1.5),
      ),
    );
  }
}
