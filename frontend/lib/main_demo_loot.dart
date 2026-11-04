import 'package:flutter/material.dart';

import 'features/loot/data/loot_mock.dart';
import 'features/loot/presentation/loot_page.dart';

void main() => runApp(const _LootDemo());

class _LootDemo extends StatelessWidget {
  const _LootDemo();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: Colors.black),
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
  bool canJoin = true, paidOk = true, live = false;
  int count = 2;
  final ValueNotifier<Set<String>> joined = ValueNotifier<Set<String>>(
    <String>{},
  );

  @override
  void dispose() {
    joined.dispose();
    super.dispose();
  }

  List<LootCard> _cards() {
    final list = mockLootCards().take(count).toList();
    if (live && list.isNotEmpty) {
      list[0] = list[0].copyWith(status: 'live', label: 'Ends in', secs: 900);
    }
    return list;
  }

  void _setJoined(String id, bool on) {
    final s = Set<String>.of(joined.value);
    on ? s.add(id) : s.remove(id);
    joined.value = s;
  }

  Widget _chip(String label, bool on, ValueChanged<bool> f) => FilterChip(
    label: Text(label, style: const TextStyle(fontSize: 11)),
    selected: on,
    onSelected: f,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _count(int n) => ChoiceChip(
    label: Text(
      '$n card${n == 1 ? '' : 's'}',
      style: const TextStyle(fontSize: 11),
    ),
    selected: count == n,
    onSelected: (_) => setState(() => count = n),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip(
                    'canJoin (Sunday)',
                    canJoin,
                    (v) => setState(() => canJoin = v),
                  ),
                  _chip('paidOk', paidOk, (v) => setState(() => paidOk = v)),
                  _chip('Live', live, (v) => setState(() => live = v)),
                  _chip(
                    'Joined l1',
                    joined.value.contains('l1'),
                    (v) => setState(() => _setJoined('l1', v)),
                  ),
                  _count(0),
                  _count(1),
                  _count(2),
                ],
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: LootPage(
                // real banners from your server; remove this line to read them from assets/images/ instead
                imageBase: 'https://rudelysmash.onrender.com/static/images/',
                cards: _cards(),
                sunDate: nextLootSundayDate(),
                canJoin: canJoin,
                paidOk: paidOk,
                joinedIds: joined,
                onBack: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Back'))),
                onOpen: (id) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Open $id')));
                  setState(() => _setJoined(id, true));
                },
                onPlayPaid: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Go to paid tournaments')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
