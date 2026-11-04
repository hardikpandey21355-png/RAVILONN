import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/rs_kit.dart';
import 'profile_group.dart' show ProfileGlass;

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(double size, int w, Color color, {double? ls, double? h}) =>
    rsT(size, w: FontWeight.values[w ~/ 100 - 1], color: color, ls: ls, h: h);
Widget _icon(String inner, String hex, double size, {String fill = 'none'}) => SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$fill" stroke="$hex" '
      'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>',
      width: size,
      height: size,
    );

const String _user = '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>';
const String _crown = '<path d="M3 8l4 4 5-7 5 7 4-4-2 11H5z"/>';

class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.userName, required this.userEmail, this.pictureUrl});
  final String userName;
  final String userEmail;
  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.sizeOf(context).width;
    final name = userName.trim().isEmpty ? 'Player' : userName;
    final email = userEmail.trim().isEmpty ? 'No email on this account' : userEmail;
    final pic = pictureUrl;
    return ProfileGlass(
      radius: 26,
      padding: const EdgeInsets.all(16),
      base: _c(12, 22, 20, .45),
      colors: [_c(110, 230, 195, .26), _c(27, 111, 92, .2)],
      stops: const [0, 1],
      angle: 180,
      border: _c(140, 240, 210, .38),
      hl: .26,
      shadow: [BoxShadow(color: _c(0, 0, 0, .28), blurRadius: 32, offset: const Offset(0, 12))],
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F2A27), Color(0xFF1B6F5C)]),
          ),
          child: Stack(fit: StackFit.expand, children: [
            Center(child: _icon(_user, '#9ff0d6', 36)),
            if (pic != null && pic.isNotEmpty)
              Image.network(pic, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: _t((vw * .054).clamp(18.0, 22.0), 700, Colors.white, h: 1.2)),
              ),
              const SizedBox(width: 6),
              _icon(_crown, '#fbbf24', 17, fill: '#fbbf24'),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(email,
                  maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: _t(12, 400, _c(196, 211, 206))),
            ),
          ]),
        ),
      ]),
    );
  }
}