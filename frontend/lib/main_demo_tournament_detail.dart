import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/tournament_detail/data/tournament_detail_mock.dart';
import 'features/tournament_detail/presentation/tournament_detail_page.dart';

void main() => runApp(const TournamentDetailDemoApp());

class TournamentDetailDemoApp extends StatelessWidget {
  const TournamentDetailDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tournament Detail Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const _DemoHome(),
    );
  }
}

class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  bool _loot = false;

  @override
  Widget build(BuildContext context) {
    final tournament =
        _loot ? TournamentDetailMock.loot : TournamentDetailMock.normal;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Normal', style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Loot', style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                ],
                selected: <bool>{_loot},
                onSelectionChanged: (s) => setState(() => _loot = s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: TournamentDetailPage(
                key: ValueKey<bool>(_loot),
                tournament: tournament,
                balance: TournamentDetailMock.balance,
                gameOk: TournamentDetailMock.gameOk,
                walletChip: const _DarkWalletPill(),
                onBack: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Back pressed')));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkWalletPill extends StatelessWidget {
  const _DarkWalletPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF14142D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x2EFFFFFF)),
      ),
      child: Text(
        '₹ 1,250',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}