part of 'tournament_detail_page.dart';

/// Bottom glass toast (tournament.html `.toast` + JS `toast(m)`).
/// Place inside the page Stack: `DetailToast(key: _toast)`.
class DetailToast extends StatefulWidget {
  const DetailToast({super.key});

  @override
  State<DetailToast> createState() => DetailToastState();
}

class DetailToastState extends State<DetailToast> {
  static const Duration _visibleFor = Duration(milliseconds: 2800);

  Timer? _timer;
  String _message = '';
  bool _visible = false;

  void show(String message) {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _message = message;
      _visible = true;
    });
    _timer = Timer(_visibleFor, () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = 150 + MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _visible ? 1.0 : 0.0),
              duration: _ms(context, 250),
              curve: Curves.easeOut,
              builder: (context, v, child) {
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - v)),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                child: _Glass(
                  r: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: _t(12, FontWeight.w400, _white, h: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}