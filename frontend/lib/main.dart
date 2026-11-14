import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/auth/auth_gate.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/auth_session.dart';
import 'core/app_update/app_update_service.dart';
import 'core/notifications/app_notifications.dart';
import 'core/payment_deep_links.dart';
import 'core/slide_route.dart';
import 'core/mock/mock_data.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/app_nav.dart';
import 'core/widgets/wallet_chip.dart';
import 'features/home/presentation/home_page.dart';
import 'features/legal/legal_page.dart';
import 'features/loot/data/loot_mock.dart';
import 'features/loot/presentation/loot_page.dart';
import 'features/matches/data/matches_repository.dart';
import 'features/matches/presentation/matches_page.dart';
import 'features/notifications/presentation/notification_inbox_page.dart';
import 'features/profile/data/profile_mock.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/presentation/profile_page.dart';
import 'features/tournament_detail/data/tournament_detail_mock.dart';
import 'features/tournament_detail/presentation/tournament_detail_page.dart';
import 'features/tournaments/data/tournament_repository.dart';
import 'features/tournaments/presentation/tournaments_page.dart';
import 'features/wallet/presentation/wallet_page.dart';
import 'features/wallet/data/wallet_repository.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppNotifications.initialize();
  await PaymentDeepLinks.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const RivalonApp());
}

class RivalonApp extends StatelessWidget {
  const RivalonApp({
    super.key,
    this.initialRoute = '/auth',
    this.tournamentRepository,
  });

  final String initialRoute;
  final TournamentRepository? tournamentRepository;

  TournamentRepository get _tournaments =>
      tournamentRepository ?? TournamentRepository.shared;

  Widget _tournamentContent(
    Widget Function(BuildContext, List<Tournament>) builder,
  ) {
    final repository = _tournaments;
    unawaited(repository.load().catchError((Object _) => repository.cached));
    return ValueListenableBuilder<List<Tournament>>(
      valueListenable: repository.tournaments,
      builder: (context, records, _) {
        if (!repository.hasLoaded) return const _TournamentLoadState();
        if (repository.loadError != null && records.isEmpty) {
          return _TournamentLoadState(
            error: repository.loadError,
            onRetry: () => unawaited(
              repository.refresh().catchError((Object _) => repository.cached),
            ),
          );
        }
        return builder(context, records);
      },
    );
  }

  static final GlobalKey<NavigatorState> _navigatorKey =
      AppNotifications.navigatorKey;
  static final RsNavObserver _navObserver = RsNavObserver();
  static bool _heldRouteQueued = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RIVALON',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      initialRoute: initialRoute,
      navigatorObservers: [_navObserver],
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: AuthSession.accountHeld,
          builder: (context, held, _) {
            if (held && !_heldRouteQueued) {
              _heldRouteQueued = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                  '/held',
                  (route) => false,
                );
              });
            } else if (!held) {
              _heldRouteQueued = false;
            }
            return ValueListenableBuilder<bool>(
              valueListenable: AuthSession.maintenanceOn,
              builder: (context, maintenance, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AppShell(
                      activeIndex: _navObserver.active.value,
                      navObserver: _navObserver,
                      navigatorKey: _navigatorKey,
                      child: child ?? const SizedBox.shrink(),
                    ),
                    if (maintenance && !held)
                      MaintenancePage(
                        message: AuthSession.maintenanceMessage.value,
                        eta: AuthSession.maintenanceEta.value,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
      routes: {
        '/held': (_) => const AccountHoldPage(),
        '/notifications': (_) => AppShell(child: const NotificationInboxPage()),
        '/terms': (_) => const LegalPage(initialIndex: 0),
        '/privacy': (_) => const LegalPage(initialIndex: 1),
        '/refund-policy': (_) => const LegalPage(initialIndex: 2),
        '/contact': (_) => const LegalPage(initialIndex: 3),
      },
      onGenerateRoute: (settings) {
        final name = settings.name;
        if (name == '/auth') {
          return MaterialPageRoute<void>(
            builder: (_) => const AuthGate(),
            settings: settings,
          );
        }
        if (name == '/login') {
          final initialMessage = settings.arguments;
          return slideRoute(
            LoginPage(
              initialMessage: initialMessage is String ? initialMessage : null,
            ),
            settings: settings,
          );
        }
        if (name == '/contact') {
          return slideRoute(
            const LegalPage(initialIndex: 3),
            settings: settings,
          );
        }
        if (name == '/') {
          return slideRoute(
            _tournamentContent(
              (context, records) => HomePage(
                onSaveGameId: ProfileRepository().saveGameId,
                onOpenTournament: (id) =>
                    Navigator.of(context).pushNamed('/tournament/$id'),
                onAppOpened: AppUpdateService().checkOnOpen,
                onTournamentTimerEnd: () => unawaited(
                  _tournaments.refresh().catchError(
                    (Object _) => _tournaments.cached,
                  ),
                ),
                tournaments: records,
              ),
            ),
            settings: settings,
          );
        }
        if (name == '/tournaments') {
          return slideRoute(
            Builder(
              builder: (context) => AppShell(
                child: _tournamentContent(
                  (context, records) => TournamentsPage(
                    walletChip: WalletChip(
                      balanceListenable: AuthSession.walletTotal,
                    ),
                    onBack: () => Navigator.of(context).pop(),
                    onOpen: (id) =>
                        Navigator.of(context).pushNamed('/tournament/$id'),
                    joinedIds: MockData.joinedIds,
                    items: records
                        .where((tournament) => !tournament.loot)
                        .toList(growable: false),
                    bottomInset: const EdgeInsets.only(bottom: 100),
                  ),
                ),
              ),
            ),
            forward: settings.arguments != false,
            settings: settings,
          );
        }
        if (name == '/matches') {
          return slideRoute(
            AppShell(
              child: MatchesPage(
                walletChip: WalletChip(
                  balanceListenable: AuthSession.walletTotal,
                ),
                onBrowseTournaments: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/tournaments'),
                onLoadMatches: MatchesRepository().load,
                bottomInset: const EdgeInsets.only(bottom: 100),
              ),
            ),
            settings: settings,
          );
        }
        if (name == '/wallet') {
          final payStatus = settings.arguments;
          return slideRoute(
            Builder(
              builder: (context) => AppShell(
                activeIndex: 3,
                child: WalletPage(
                  walletChip: WalletChip(
                    balanceListenable: AuthSession.walletTotal,
                  ),
                  onOpenProfile: () =>
                      Navigator.of(context).pushNamed('/profile'),
                  onTotalChanged: (total) =>
                      AuthSession.walletTotal.value = total,
                  repository: WalletRepository(),
                  initialPayStatus: payStatus is String ? payStatus : null,
                  bottomInset: const EdgeInsets.only(bottom: 100),
                ),
              ),
            ),
            forward: _navObserver.active.value != 4,
            settings: settings,
          );
        }
        if (name == '/profile') {
          return slideRoute(
            Builder(
              builder: (context) => AppShell(
                activeIndex: 4,
                child: ProfilePage(
                  walletChip: WalletChip(
                    balanceListenable: AuthSession.walletTotal,
                  ),
                  userName: AuthSession.name.value,
                  userEmail: AuthSession.email.value,
                  pictureUrl: AuthSession.picture.value,
                  initialGame: GameIdState(
                    ign: AuthSession.ign.value,
                    uid: AuthSession.gameUid.value,
                    saved: AuthSession.gameOk.value,
                  ),
                  initialUpi: UpiState(
                    upi: AuthSession.upi.value,
                    hasShot: AuthSession.hasUpiShot.value,
                  ),
                  initialPush: AuthSession.pushNotifications.value,
                  initialReminders: AuthSession.matchReminders.value,
                  initialResults: AuthSession.resultAlerts.value,
                  onSaveGameId: ProfileRepository().saveGameId,
                  onSaveUpi: ProfileRepository().saveUpi,
                  onPickScreenshot: () =>
                      ImagePicker().pickImage(source: ImageSource.gallery),
                  onSaveNotifSettings:
                      ({
                        required bool push,
                        required bool reminders,
                        required bool results,
                      }) async {
                        await ProfileRepository().saveNotifSettings(
                          push: push,
                          reminders: reminders,
                          results: results,
                        );
                        if (push) {
                          await AppNotifications.registerForCurrentUser();
                        }
                      },
                  onLoadNotifSettings: ProfileRepository().loadNotifSettings,
                  onLoadStats: ProfileRepository().loadStats,
                  onOpenWallet: () =>
                      Navigator.of(context).pushNamed('/wallet'),
                  onOpenNotifications: () =>
                      Navigator.of(context).pushNamed('/notifications'),
                  onOpenUrl: (url) async {
                    final opened = await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened) {
                      throw StateError('No external app could open $url.');
                    }
                  },
                  onLogout: () async {
                    _tournaments.stopPolling();
                    await AuthRepository().signOut();
                    final preferences = await SharedPreferences.getInstance();
                    await preferences.remove('rs_intro_seen');
                    final navigator = _navigatorKey.currentState;
                    if (navigator == null) {
                      throw StateError('Navigator is not ready for logout.');
                    }
                    navigator.pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  },
                  onDeleteAccount: () async {
                    _tournaments.stopPolling();
                    await AuthRepository().deleteAccount();
                    final preferences = await SharedPreferences.getInstance();
                    await preferences.remove('rs_intro_seen');
                    final navigator = _navigatorKey.currentState;
                    if (navigator == null) {
                      throw StateError(
                        'Navigator is not ready after account deletion.',
                      );
                    }
                    navigator.pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  },
                  bottomInset: const EdgeInsets.only(bottom: 100),
                ),
              ),
            ),
            forward: true,
            settings: settings,
          );
        }
        if (name != null && name.startsWith('/tournament/')) {
          final id = Uri.decodeComponent(name.substring('/tournament/'.length));
          final tournament = _tournaments.find(id);
          if (tournament == null) {
            return slideRoute(
              PlaceholderPage(name: name),
              standaloneTransition: true,
              settings: settings,
            );
          }
          final detail = _toTournamentDetail(tournament);
          return slideRoute(
            Builder(
              builder: (context) => ValueListenableBuilder<int>(
                valueListenable: AuthSession.walletTotal,
                builder: (context, balance, _) => ValueListenableBuilder<bool>(
                  valueListenable: AuthSession.gameOk,
                  builder: (context, gameOk, _) =>
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: MockData.joinedIds,
                        builder: (context, joinedIds, _) =>
                            TournamentDetailPage(
                              tournament: detail,
                              walletChip: WalletChip(
                                balanceListenable: AuthSession.walletTotal,
                                loot: detail.isLoot,
                              ),
                              balance: balance,
                              gameOk: gameOk,
                              joined: joinedIds.contains(id),
                              onBack: () {
                                final navigator = Navigator.of(context);
                                if (navigator.canPop()) {
                                  navigator.pop();
                                } else {
                                  navigator.pushNamedAndRemoveUntil(
                                    '/',
                                    (route) => false,
                                  );
                                }
                              },
                              onOpenProfile: () =>
                                  Navigator.of(context).pushNamed('/profile'),
                              onViewMatches: () =>
                                  Navigator.of(context).pushNamed('/matches'),
                              onBrowseTournaments: () => Navigator.of(
                                context,
                              ).pushNamed('/tournaments', arguments: false),
                              onRefreshGame: () async =>
                                  AuthSession.gameOk.value,
                              onLoadSlots: () async {
                                return _tournaments.loadSlots(id);
                              },
                              onJoin: (slot) => _tournaments.join(id, slot),
                            ),
                      ),
                ),
              ),
            ),
            standaloneTransition: true,
            settings: settings,
          );
        }
        if (name == '/loot') {
          return slideRoute(
            Builder(
              builder: (context) => ValueListenableBuilder<Set<String>>(
                valueListenable: MockData.joinedIds,
                builder: (context, joinedIds, _) => _tournamentContent(
                  (context, records) => LootPage(
                    walletChip: WalletChip(
                      balanceListenable: AuthSession.walletTotal,
                      loot: true,
                    ),
                    cards: lootCardsFrom(records),
                    sunDate: nextLootSundayDate(),
                    canJoin: canJoinLootToday(),
                    paidOk: MockData.hasPaidTournamentJoined,
                    joinedIds: MockData.joinedIds,
                    onBack: () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                      } else {
                        navigator.pushNamedAndRemoveUntil(
                          '/',
                          (route) => false,
                        );
                      }
                    },
                    onOpen: (id) =>
                        Navigator.of(context).pushNamed('/tournament/$id'),
                    onPlayPaid: () =>
                        Navigator.of(context).pushNamed('/tournaments'),
                  ),
                ),
              ),
            ),
            standaloneTransition: true,
            settings: settings,
          );
        }
        return slideRoute(
          PlaceholderPage(name: name ?? ''),
          settings: settings,
        );
      },
    );
  }
}

class _RedSkullPainter extends CustomPainter {
  const _RedSkullPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.save();
    canvas.scale(scale);
    final red = Paint()..color = const Color(0xFFFF4B5C);
    final dark = Paint()..color = Colors.black;
    canvas.drawOval(const Rect.fromLTWH(8, 5, 48, 42), red);
    final jaw = Path()
      ..moveTo(13, 34)
      ..lineTo(51, 34)
      ..lineTo(47, 52)
      ..lineTo(41, 58)
      ..lineTo(23, 58)
      ..lineTo(17, 52)
      ..close();
    canvas.drawPath(jaw, red);
    canvas.drawOval(const Rect.fromLTWH(16, 20, 13, 13), dark);
    canvas.drawOval(const Rect.fromLTWH(35, 20, 13, 13), dark);
    final nose = Path()
      ..moveTo(32, 34)
      ..lineTo(27, 41)
      ..lineTo(37, 41)
      ..close();
    canvas.drawPath(nose, dark);
    final teeth = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final x in [25.0, 32.0, 39.0]) {
      canvas.drawLine(Offset(x, 47), Offset(x, 56), teeth);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AccountHoldPage extends StatelessWidget {
  const AccountHoldPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CustomPaint(
                          size: Size(58, 58),
                          painter: _RedSkullPainter(),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Account on hold',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'We detected activity on your account that appears '
                          'suspicious. As a precaution, we have placed your '
                          'account on hold. If you think this is a mistake, '
                          'contact our support team.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/contact'),
                          icon: const Icon(Icons.support_agent_rounded),
                          label: const Text('Contact us for help or support'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () async {
                  await AuthRepository().signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key, required this.message, required this.eta});

  final String message;
  final String eta;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  bool _openingContact = false;

  Future<void> _openContact() async {
    final navigator = AppNotifications.navigatorKey.currentState;
    if (navigator == null) return;
    setState(() => _openingContact = true);
    final wasMaintenanceOn = AuthSession.maintenanceOn.value;
    AuthSession.maintenanceOn.value = false;
    try {
      await navigator.pushNamed('/contact');
    } finally {
      if (wasMaintenanceOn) AuthSession.maintenanceOn.value = true;
      if (mounted) setState(() => _openingContact = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_openingContact)
                const SizedBox.shrink()
              else ...[
                const Icon(
                  Icons.build_circle_outlined,
                  size: 56,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Under maintenance',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(widget.message, textAlign: TextAlign.center),
                if (widget.eta.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(widget.eta, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _openContact,
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Contact us for help or support'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _TournamentLoadState extends StatelessWidget {
  const _TournamentLoadState({this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: error == null
          ? const CircularProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not load tournaments. Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 12),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
    ),
  );
}

TournamentDetail _toTournamentDetail(Tournament tournament) {
  final defaults = TournamentDetailMock.normal;
  final detailParts = tournament.detail
      .split('|')
      .map((part) => part.trim())
      .toList(growable: false);
  final playerCounts = tournament.players.split('/');

  int? parseNumber(String? value) {
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  return TournamentDetail(
    id: tournament.id,
    game: tournament.game,
    mode: tournament.mode,
    team: tournament.teamType.isNotEmpty
        ? tournament.teamType
        : detailParts.isNotEmpty && detailParts.first.isNotEmpty
        ? detailParts.first
        : defaults.team,
    map: detailParts.length > 1 && detailParts[1].isNotEmpty
        ? detailParts[1]
        : defaults.map,
    img: tournament.img,
    imageUrl: tournament.bannerUrl,
    status: tournament.status,
    prize:
        parseNumber(tournament.prize) ??
        (tournament.remote ? 0 : defaults.prize),
    fee: parseNumber(tournament.fee) ?? (tournament.remote ? 0 : defaults.fee),
    perKill: tournament.perKill == null && tournament.remote
        ? null
        : parseNumber(tournament.perKill) ?? defaults.perKill,
    slots: playerCounts.length > 1
        ? (parseNumber(playerCounts[1]) ??
              (tournament.remote ? 0 : defaults.slots))
        : defaults.slots,
    joinedCount: playerCounts.isNotEmpty
        ? (parseNumber(playerCounts.first) ??
              (tournament.remote ? 0 : defaults.joinedCount))
        : defaults.joinedCount,
    reservedCount: tournament.reservedCount,
    secs: tournament.secs,
    label: tournament.label,
    when: tournament.when,
    prizes: tournament.remote ? tournament.prizes : defaults.prizes,
    loot: tournament.loot,
  );
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(name == '/' ? 'Home' : name),
      ),
      body: Center(
        child: Text(
          'Page "$name" coming soon',
          style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}
