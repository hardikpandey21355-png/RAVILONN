import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/rs_kit.dart';
import '../data/profile_repository.dart';
import '../data/profile_mock.dart';
import 'game_id_card.dart';
import 'help_sheet.dart';
import 'player_card.dart';
import 'profile_group.dart';
import 'profile_toast.dart';
import 'rules_sheet.dart';
import 'stats_row.dart';
import 'telegram_banner.dart';
import 'upi_sheet.dart';

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(double size, int w, Color color, {double? ls, double? h}) =>
    rsT(size, w: FontWeight.values[w ~/ 100 - 1], color: color, ls: ls, h: h);
const Curve _ease = kRsEase;

String _inr(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final last = digits.substring(digits.length - 3);
  var leading = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (leading.length > 2) {
    groups.insert(0, leading.substring(leading.length - 2));
    leading = leading.substring(0, leading.length - 2);
  }
  groups.insert(0, leading);
  return '${groups.join(',')},$last';
}

abstract final class _I {
  static const wallet =
      '<path d="M3 7a2 2 0 0 1 2-2h13v4"/><path d="M3 7v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2z"/><circle cx="16" cy="14" r="1"/>';
  static const flame =
      '<path d="M12 3c1 4 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z"/>';
  static const clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
  static const trophy =
      '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>';
  static const ticket =
      '<path d="M3 9a2 2 0 0 0 0 6v3h18v-3a2 2 0 0 1 0-6V6H3z"/><path d="M13 6v12" stroke-dasharray="2 2"/>';
  static const users =
      '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6.5 6.5 0 0 1 3.5 6"/>';
  static const lock =
      '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>';
}

const String _tgUrl = 'https://t.me/ravalon_smash';
const List<double> _delays = [
  0,
  .01,
  .035,
  .06,
  .085,
  .105,
  .125,
  .145,
  .165,
  .185,
  .205,
  .225,
  .245,
  .265,
];

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.walletChip,
    this.userName = 'Player',
    this.userEmail = '',
    this.pictureUrl,
    this.initialGame = const GameIdState(),
    this.initialUpi = const UpiState(),
    this.onSaveGameId,
    this.onSaveUpi,
    this.onPickScreenshot,
    this.onSaveNotifSettings,
    this.onLoadNotifSettings,
    this.onLoadStats,
    this.initialPush = true,
    this.initialReminders = true,
    this.initialResults = true,
    this.onOpenUrl,
    this.onOpenWallet,
    this.onOpenNotifications,
    this.onLogout,
    this.onDeleteAccount,
    this.bottomInset = const EdgeInsets.only(bottom: 100),
  });

  final Widget walletChip;
  final String userName;
  final String userEmail;
  final String? pictureUrl;
  final GameIdState initialGame;
  final UpiState initialUpi;
  final Future<GameIdResult> Function(String ign, String uid)? onSaveGameId;
  final Future<UpiResult> Function(String upi, XFile? shot)? onSaveUpi;
  final Future<XFile?> Function()? onPickScreenshot;
  final Future<void> Function({
    required bool push,
    required bool reminders,
    required bool results,
  })?
  onSaveNotifSettings;
  final Future<Map<String, bool>> Function()? onLoadNotifSettings;
  final Future<ProfileStats> Function()? onLoadStats;
  final bool initialPush;
  final bool initialReminders;
  final bool initialResults;
  final Future<void> Function(String)? onOpenUrl;
  final VoidCallback? onOpenWallet;
  final VoidCallback? onOpenNotifications;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onDeleteAccount;
  final EdgeInsets bottomInset;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 565),
  );
  bool _riseStarted = false;
  late UpiState _upi = widget.initialUpi;
  late bool _push = widget.initialPush;
  late bool _remind = widget.initialReminders;
  late bool _results = widget.initialResults;
  String _pushSub = 'Get match and prize alerts on this device';
  ProfileStats? _stats;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotifSettings());
    unawaited(_loadStats());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_riseStarted) return;
    _riseStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _rise.value = 1;
    } else {
      _rise.forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  Future<void> _loadNotifSettings() async {
    try {
      final settings = await widget.onLoadNotifSettings?.call();
      if (!mounted || settings == null) return;
      setState(() {
        _push = settings['push'] ?? true;
        _remind = settings['reminders'] ?? true;
        _results = settings['results'] ?? true;
        _pushSub = _push
            ? 'You will get match and prize alerts on this device.'
            : 'Notifications are off on this device.';
      });
    } catch (error) {
      if (mounted) _showSettingsError(error);
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await widget.onLoadStats?.call();
      if (!mounted || stats == null) return;
      setState(() {
        _stats = stats;
        _statsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statsError = 'Stats could not be loaded. Please try again later.';
      });
    }
  }

  Future<void> _updateNotifSettings({
    bool? push,
    bool? reminders,
    bool? results,
  }) async {
    final oldPush = _push;
    final oldReminders = _remind;
    final oldResults = _results;
    final nextPush = push ?? _push;
    final nextReminders = reminders ?? _remind;
    final nextResults = results ?? _results;
    setState(() {
      _push = nextPush;
      _remind = nextReminders;
      _results = nextResults;
      _pushSub = nextPush
          ? 'You will get match and prize alerts on this device.'
          : 'Notifications are off on this device.';
    });
    try {
      await widget.onSaveNotifSettings?.call(
        push: nextPush,
        reminders: nextReminders,
        results: nextResults,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _push = oldPush;
        _remind = oldReminders;
        _results = oldResults;
        _pushSub = oldPush
            ? 'You will get match and prize alerts on this device.'
            : 'Notifications are off on this device.';
      });
      _showSettingsError(error);
    }
  }

  void _showSettingsError(Object error) {
    ProfileToast.show(
      context,
      'Could not save notification settings',
      ProfileToastType.err,
      error.toString().isEmpty
          ? 'Network problem. Try again.'
          : error.toString(),
    );
  }

  void _openUpi() {
    showProfileSheet<void>(
      context,
      (_) => UpiSheet(
        initial: _upi,
        onSave: widget.onSaveUpi ?? mockSaveUpi,
        onPickScreenshot: widget.onPickScreenshot ?? mockPickScreenshot,
        onSaved: (r) {
          AuthSession.upi.value = r.upi;
          AuthSession.hasUpi.value = r.upi.isNotEmpty;
          AuthSession.hasUpiShot.value = r.hasShot;
          if (mounted) {
            setState(() => _upi = UpiState(upi: r.upi, hasShot: r.hasShot));
          }
        },
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      await widget.onOpenUrl?.call(url);
    } catch (e) {
      debugPrint('ProfilePage: could not open $url ($e)');
      if (mounted) {
        ProfileToast.show(
          context,
          'Could not open link',
          ProfileToastType.err,
          'Please try again.',
        );
      }
    }
  }

  Future<void> _logout() async {
    final off = MediaQuery.disableAnimationsOf(context);
    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cancel',
      barrierColor: _c(0, 0, 0, .6),
      transitionDuration: off
          ? Duration.zero
          : const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const _LogoutDialog(),
      transitionBuilder: (_, a, _, child) {
        final v = _ease.transform(a.value);
        return Opacity(
          opacity: v,
          child: Transform.scale(scale: .94 + .06 * v, child: child),
        );
      },
    );
    if (ok == true) {
      try {
        await widget.onLogout?.call();
      } catch (e) {
        debugPrint('ProfilePage: logout failed ($e)');
        if (mounted) {
          ProfileToast.show(
            context,
            'Could not log out',
            ProfileToastType.err,
            'Please try again.',
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final off = MediaQuery.disableAnimationsOf(context);
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cancel',
      barrierColor: _c(0, 0, 0, .72),
      transitionDuration: off
          ? Duration.zero
          : const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const _DeleteAccountDialog(),
      transitionBuilder: (_, animation, _, child) {
        final value = _ease.transform(animation.value);
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: .94 + .06 * value, child: child),
        );
      },
    );
    if (!mounted || confirmed != true) return;
    final deleteAccount = widget.onDeleteAccount;
    if (deleteAccount == null) {
      ProfileToast.show(
        context,
        'Could not delete account',
        ProfileToastType.err,
        'Please try again later.',
      );
      return;
    }

    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Deleting account',
        barrierColor: _c(0, 0, 0, .72),
        pageBuilder: (_, _, _) => const _DeletingAccountDialog(),
      ),
    );
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      await deleteAccount();
    } catch (error) {
      debugPrint('ProfilePage: account deletion failed ($error)');
      if (!mounted) return;
      navigator.pop();
      ProfileToast.show(
        context,
        'Could not delete account',
        ProfileToastType.err,
        error.toString(),
      );
    }
  }

  Widget _r(int i, Widget child) => _Rise(anim: _rise, i: i, child: child);

  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.sizeOf(context).width;
    final upiSaved = _upi.upi.isNotEmpty;
    return Material(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                14,
                14,
                14,
                0,
              ).add(widget.bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1 header
                  _r(
                    0,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Profile',
                                style:
                                    _t(
                                      (vw * .05).clamp(18.0, 22.0),
                                      700,
                                      Colors.white,
                                      h: 1.15,
                                    ).copyWith(
                                      shadows: [
                                        Shadow(
                                          color: _c(0, 0, 0, .5),
                                          blurRadius: 14,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                              ),
                              Text(
                                'Manage • Verify • Play',
                                softWrap: false,
                                style: _t(11, 400, _c(156, 163, 199)).copyWith(
                                  shadows: [
                                    Shadow(
                                      color: _c(0, 0, 0, .5),
                                      blurRadius: 14,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        widget.walletChip,
                      ],
                    ),
                  ),
                  // 2 player card
                  _r(
                    1,
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: PlayerCard(
                        userName: widget.userName,
                        userEmail: widget.userEmail,
                        pictureUrl: widget.pictureUrl,
                      ),
                    ),
                  ),
                  // 3 stats
                  _r(
                    2,
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StatsRow(
                            matches: _stats?.matches.toString() ?? '—',
                            wins: _stats?.wins.toString() ?? '—',
                            kills: _stats?.kills.toString() ?? '—',
                            earned: _stats == null
                                ? '—'
                                : '₹${_inr(_stats!.earned)}',
                          ),
                          if (_statsError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                _statsError!,
                                textAlign: TextAlign.center,
                                style: _t(11, 400, _c(248, 113, 113)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 4 telegram
                  _r(
                    3,
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TelegramBanner(
                        onTap: () => unawaited(_openUrl(_tgUrl)),
                      ),
                    ),
                  ),
                  // 5-6 game id
                  _r(4, const _H2('Game ID')),
                  _r(
                    5,
                    GameIdCard(
                      initial: widget.initialGame,
                      onSave: widget.onSaveGameId ?? mockSaveGameId,
                      onSaved: (result) {
                        AuthSession.ign.value = result.ign;
                        AuthSession.gameUid.value = result.uid;
                        AuthSession.gameOk.value = true;
                      },
                    ),
                  ),
                  // 7-8 verification
                  _r(6, const _H2('Verification')),
                  _r(
                    7,
                    ProfileGroup(
                      children: [
                        ProfileRow(
                          icon: _I.wallet,
                          title: 'UPI for withdrawals',
                          sub: upiSaved
                              ? _upi.upi
                              : 'Needed to withdraw your winnings',
                          trailing: ProfileStatusChip(
                            label: upiSaved ? 'Added' : 'Start',
                            ok: upiSaved,
                          ),
                          onTap: _openUpi,
                        ),
                      ],
                    ),
                  ),
                  // 9-10 settings
                  _r(8, const _H2('Settings')),
                  _r(
                    9,
                    ProfileGroup(
                      children: [
                        ProfileRow(
                          icon: _I.flame,
                          title: 'Push notifications',
                          sub: _pushSub,
                          trailing: ProfileSwitch(
                            value: _push,
                            onChanged: (v) =>
                                unawaited(_updateNotifSettings(push: v)),
                            label: 'Push notifications',
                          ),
                        ),
                        ProfileRow(
                          icon: _I.clock,
                          title: 'Match reminders',
                          sub: 'Alert 15 min before the room opens',
                          trailing: ProfileSwitch(
                            value: _remind,
                            onChanged: (v) =>
                                unawaited(_updateNotifSettings(reminders: v)),
                            label: 'Match reminders',
                          ),
                        ),
                        ProfileRow(
                          icon: _I.trophy,
                          title: 'Result and prize alerts',
                          sub: 'When results are declared',
                          trailing: ProfileSwitch(
                            value: _results,
                            onChanged: (v) =>
                                unawaited(_updateNotifSettings(results: v)),
                            label: 'Result and prize alerts',
                          ),
                        ),
                        ProfileRow(
                          icon: _I.ticket,
                          title: 'Transaction history',
                          sub: 'Payments, entry fees and winnings',
                          chevron: true,
                          onTap: widget.onOpenWallet ?? () {},
                        ),
                        ProfileRow(
                          icon: _I.clock,
                          title: 'Notification inbox',
                          sub: 'View account, wallet and tournament updates',
                          chevron: true,
                          onTap: widget.onOpenNotifications ?? () {},
                        ),
                      ],
                    ),
                  ),
                  // 11-12 help
                  _r(10, const _H2('Help')),
                  _r(
                    11,
                    ProfileGroup(
                      children: [
                        ProfileRow(
                          icon: _I.users,
                          title: 'Help and support',
                          sub: 'Payment or match problems',
                          chevron: true,
                          onTap: () => showProfileSheet<void>(
                            context,
                            (_) => HelpSheet(
                              userEmail: widget.userEmail,
                              onOpenUrl: _openUrl,
                            ),
                          ),
                        ),
                        ProfileRow(
                          icon: _I.lock,
                          title: 'Rules and fair play',
                          sub: 'Terms, refunds and responsible gaming',
                          chevron: true,
                          onTap: () => showProfileSheet<void>(
                            context,
                            (_) => const RulesSheet(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 13 account actions
                  _r(
                    12,
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProfileButton(
                            label: 'Log out',
                            kind: ProfileButtonKind.danger,
                            onTap: _logout,
                          ),
                          const SizedBox(height: 10),
                          ProfileButton(
                            label: 'Delete account',
                            kind: ProfileButtonKind.danger,
                            onTap: _deleteAccount,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 14 version
                  _r(
                    13,
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        'Ravilon v1.0',
                        textAlign: TextAlign.center,
                        style: _t(10, 400, const Color(0xFF8D9A95)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// rise: opacity 0->1 + translateY 18->0, 300ms, staggered per block.
class _Rise extends StatelessWidget {
  const _Rise({required this.anim, required this.i, required this.child});
  final Animation<double> anim;
  final int i;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (_, ch) {
        const total = .565;
        final v = Interval(
          _delays[i] / total,
          (_delays[i] + .3) / total,
          curve: _ease,
        ).transform(anim.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - v)),
            child: ch,
          ),
        );
      },
    );
  }
}

class _H2 extends StatelessWidget {
  const _H2(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4CC9AA), Color(0xFF1B6F5C)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: _t(12, 600, const Color(0xFF9FD9C7), ls: 12 * .14),
        ),
      ],
    ),
  );
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: ProfileGlass(
              radius: 24,
              padding: const EdgeInsets.all(20),
              base: _c(8, 16, 14, .9),
              colors: [_c(255, 255, 255, .12), _c(255, 255, 255, .03)],
              stops: const [0, 1],
              angle: 180,
              border: _c(255, 255, 255, .16),
              hl: .18,
              shadow: [
                BoxShadow(
                  color: _c(0, 0, 0, .55),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Log out of Rivalon?',
                    textAlign: TextAlign.center,
                    style: _t(16, 600, Colors.white, h: 1.3),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ProfileButton(
                          label: 'Cancel',
                          kind: ProfileButtonKind.ghost,
                          height: 46,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ProfileButton(
                          label: 'Log out',
                          kind: ProfileButtonKind.danger,
                          height: 46,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ProfileGlass(
              radius: 24,
              padding: const EdgeInsets.all(20),
              base: _c(30, 8, 10, .97),
              colors: [_c(255, 107, 107, .2), _c(255, 255, 255, .035)],
              stops: const [0, 1],
              angle: 180,
              border: _c(255, 107, 107, .42),
              hl: .1,
              shadow: [
                BoxShadow(
                  color: _c(0, 0, 0, .6),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Delete account permanently?',
                    textAlign: TextAlign.center,
                    style: _t(17, 700, Colors.white, h: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your profile, wallet, transactions, deposits, withdrawals, '
                    'tournament history, and Firebase data will be permanently '
                    'deleted. Resolve pending withdrawals first. This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: _t(12, 400, _c(255, 220, 220), h: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ProfileButton(
                          label: 'Cancel',
                          kind: ProfileButtonKind.ghost,
                          height: 46,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ProfileButton(
                          label: 'Delete',
                          kind: ProfileButtonKind.danger,
                          height: 46,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletingAccountDialog extends StatelessWidget {
  const _DeletingAccountDialog();

  @override
  Widget build(BuildContext context) {
    return const Material(
      type: MaterialType.transparency,
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF6B6B),
          semanticsLabel: 'Deleting account and data',
        ),
      ),
    );
  }
}
