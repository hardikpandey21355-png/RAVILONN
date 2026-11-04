import 'package:flutter/material.dart';

import 'features/matches/presentation/matches_page.dart';

void main() => runApp(const _MatchesDemo());

class _MatchesDemo extends StatelessWidget {
  const _MatchesDemo();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: Colors.black),
      home: Builder(
        builder: (context) => MatchesPage(
          // real banners from your server (or use the default 'assets/images/' if the files are in the project)
          imageBase: 'https://rudelysmash.onrender.com/static/images/',
          onBrowseTournaments: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Browse tournaments (navigation goes here)'))),
          onLeave: (id) async {
            await Future<void>.delayed(const Duration(milliseconds: 400)); // pretend API call
            return true;
          },
        ),
      ),
    );
  }
}