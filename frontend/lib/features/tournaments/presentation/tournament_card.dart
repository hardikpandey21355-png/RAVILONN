part of 'tournaments_page.dart';

/// One tournament card: image on the left (40%), numbers + button on the right (60%).
class TournamentCardView extends StatelessWidget {
  const TournamentCardView({
    super.key,
    required this.card,
    required this.secs,
    this.joined = false,
    this.onOpen,
  });

  final TournamentCard card;

  /// Seconds left. Only the timer text rebuilds when this changes.
  final ValueListenable<int> secs;
  final bool joined;

  /// Card tap or "Join Now" tap (not used for live cards).
  final VoidCallback? onOpen;

  bool get _live => card.status == 'live';

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      scale: .985,
      ms: 350,
      onTap: _live ? null : onOpen,
      builder: (context, down) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: down ? 1 : 0),
          duration: _d(context, 300),
          builder: (context, t, _) {
            return _Glass(
              height: 160,
              radius: 26,
              gradient: _g(
                145,
                [
                  rsC(255, 255, 255, .13),
                  rsC(255, 255, 255, .035),
                  rsC(255, 255, 255, .07),
                ],
                const [0, .45, 1],
              ),
              color: rsC(12, 16, 15, .5),
              border: joined
                  ? rsC(74, 222, 128, .55)
                  : Color.lerp(
                      rsC(255, 255, 255, .14),
                      rsC(110, 230, 195, .35),
                      t,
                    )!,
              blur: 22,
              inset: rsC(255, 255, 255, .18),
              shadows: [
                _Sh(0, 12, 32, rsC(0, 0, 0, .4)),
                if (joined) _Sh(0, 0, 16, rsC(34, 197, 94, .18)),
              ],
              clipInner: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: _imagePane(context)),
                  Expanded(flex: 3, child: _infoPane()),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------ left: image
  Widget _imagePane(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final modeSize = (w * .036).clamp(12.0, 14.0).toDouble();
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: _g(135, const [Color(0xFF0C2A24), Color(0xFF101414)]),
          ),
        ),
        card.bannerUrl.isNotEmpty
            ? Image.network(
                card.bannerUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stack) {
                  debugPrint('Tournament image failed to load: $error');
                  return const SizedBox.shrink(); // the dark teal gradient below stays visible
                },
              )
            : Image.asset(
                'assets/images/${card.img}',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stack) {
                  debugPrint(
                    'Tournament image failed to load: assets/images/${card.img} -> $error',
                  );
                  return const SizedBox.shrink();
                },
              ),
        // bottom -> top dark fade
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [rsC(0, 0, 0, .85), rsC(0, 0, 0, 0)],
              stops: const [0, .6],
            ),
          ),
        ),
        // left -> right fade into the info side
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [rsC(10, 16, 15, 0), rsC(10, 16, 15, .95)],
              stops: const [.45, 1],
            ),
          ),
        ),
        Positioned(top: 8, left: 8, child: _statusTag()),
        if (card.teamType.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: rsC(8, 14, 13, .78),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: rsC(255, 255, 255, .28)),
              ),
              child: Text(
                card.teamType.toUpperCase(),
                style: _t(9, FontWeight.w700, Colors.white),
              ),
            ),
          ),
        Positioned(
          left: 10,
          right: 6,
          bottom: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Glass(
                width: 32,
                height: 32,
                radius: 11,
                color: rsC(8, 14, 13, .7),
                border: rsC(255, 255, 255, .26),
                blur: 10,
                saturate: false,
                alignment: Alignment.center,
                child: const RsIcon(
                  'flame',
                  size: 18,
                  color: Color(0xFFFB923C),
                  stroke: 1.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                card.mode,
                style: _t(modeSize, FontWeight.w700, Colors.white, h: 1.15),
              ),
              const SizedBox(height: 2),
              Text(
                card.detail,
                style: _t(10, FontWeight.w400, rsC(196, 211, 206)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _live ? const Color(0xFFDC2626) : const Color(0xFF7C3AED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_live) ...[const _BlinkDot(), const SizedBox(width: 5)],
          Text(
            _live ? 'LIVE' : 'UPCOMING',
            style: _t(9, FontWeight.w600, Colors.white),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ right: numbers + button
  Widget _infoPane() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _kv(
                      'trophy',
                      const Color(0xFFFBBF24),
                      card.prize,
                      'Prize Pool',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kv(
                      'ticket',
                      const Color(0xFF3B82F6),
                      card.fee,
                      'Entry Fee',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _kv(
                      'users',
                      const Color(0xFF22D3EE),
                      card.players,
                      'Players',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _timerKv()),
                ],
              ),
            ],
          ),
          _button(),
        ],
      ),
    );
  }

  Widget _kv(String icon, Color color, String text, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RsIcon(icon, size: 15, color: color, stroke: 1.8),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: _t(13, FontWeight.w600, Colors.white),
              ),
            ),
          ],
        ),
        Text(label, style: _t(9, FontWeight.w400, rsC(154, 168, 163))),
      ],
    );
  }

  Widget _timerKv() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: secs,
          builder: (context, s, _) => Text(
            _clock(s),
            maxLines: 1,
            softWrap: false,
            style: _t(
              12,
              FontWeight.w600,
              rsC(216, 255, 241),
              ls: .5,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        Text(card.label, style: _t(9, FontWeight.w400, rsC(154, 168, 163))),
      ],
    );
  }

  Widget _button() {
    if (_live) {
      return _Glass(
        height: 36,
        radius: 999,
        color: rsC(239, 68, 68, .1),
        border: rsC(239, 68, 68, .45),
        blur: 14,
        saturate: false,
        alignment: Alignment.center,
        child: Text(
          'Match in progress',
          style: _t(12, FontWeight.w600, rsC(252, 165, 165)),
        ),
      );
    }
    final textColor = joined ? rsC(220, 252, 231) : rsC(234, 255, 247);
    return RsPress(
      scale: .93,
      onTap: onOpen,
      child: _Glass(
        height: 36,
        radius: 999,
        gradient: joined
            ? _g(180, [rsC(74, 222, 128, .34), rsC(21, 128, 61, .26)])
            : _gbtnGrad,
        color: joined ? rsC(8, 24, 16, .5) : _gbtnColor,
        border: joined ? rsC(134, 239, 172, .5) : _gbtnBorder,
        blur: 18,
        inset: rsC(255, 255, 255, joined ? .28 : .26),
        shadows: [_Sh(0, 6, 18, rsC(0, 0, 0, .35))],
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              joined ? 'Joined' : 'Join Now',
              style: _t(13, FontWeight.w600, textColor),
            ),
            if (!joined) ...[
              const SizedBox(width: 6),
              const RsIcon(
                'arrow',
                size: 15,
                color: Color(0xFFEAFFF7),
                stroke: 1.8,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
