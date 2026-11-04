import 'package:flutter/foundation.dart';

class AuthSessionData {
  const AuthSessionData({
    required this.uid,
    required this.name,
    required this.email,
    required this.picture,
    required this.walletTotal,
    required this.gameOk,
    required this.ign,
    required this.gameUid,
    required this.upi,
    required this.hasUpiShot,
    required this.hasUpi,
    required this.deposited,
    required this.winnings,
    required this.bonus,
    required this.dailyLeft,
    required this.limits,
    required this.notifSettings,
    required this.maintenanceOn,
    required this.maintenanceMessage,
    required this.maintenanceEta,
    this.paymentMethod = 'gateway',
  });

  final String uid;
  final String name;
  final String email;
  final String? picture;
  final int walletTotal;
  final bool gameOk;
  final String ign;
  final String gameUid;
  final String upi;
  final bool hasUpiShot;
  final bool hasUpi;
  final int deposited;
  final int winnings;
  final int bonus;
  final int dailyLeft;
  final Map<String, dynamic> limits;
  final Map<String, dynamic> notifSettings;
  final bool maintenanceOn;
  final String maintenanceMessage;
  final String maintenanceEta;
  final String paymentMethod;

  factory AuthSessionData.fromJson(Map<String, dynamic> json) {
    final user = _asMap(json['user']);
    final wallet = _asMap(json['wallet']);
    final maintenance = _asMap(json['maintenance']);
    return AuthSessionData(
      uid: _string(user['uid']),
      name: _string(user['name'], fallback: 'Player'),
      email: _string(user['email']),
      picture: _nullableString(user['picture']),
      walletTotal: _integer(wallet['total']),
      gameOk: json['gameOk'] == true,
      ign: _string(user['ign']),
      gameUid: _string(user['gameUid']),
      upi: _string(user['upi']),
      hasUpiShot: user['hasUpiShot'] == true,
      hasUpi: json['hasUpi'] == true,
      deposited: _integer(wallet['deposited']),
      winnings: _integer(wallet['winnings']),
      bonus: _integer(wallet['bonus']),
      dailyLeft: _integer(json['dailyLeft']),
      limits: _asMap(json['limits']),
      notifSettings: _asMap(user['notifSettings']),
      maintenanceOn: maintenance['on'] == true,
      maintenanceMessage: _string(
        maintenance['message'],
        fallback: 'We will be back shortly.',
      ),
      maintenanceEta: _string(maintenance['eta']),
      paymentMethod: _string(json['paymentMethod'], fallback: 'gateway'),
    );
  }

  void apply() {
    AuthSession.userId.value = uid;
    AuthSession.name.value = name;
    AuthSession.email.value = email;
    AuthSession.picture.value = picture;
    AuthSession.walletTotal.value = walletTotal;
    AuthSession.gameOk.value = gameOk;
    AuthSession.ign.value = ign;
    AuthSession.gameUid.value = gameUid;
    AuthSession.upi.value = upi;
    AuthSession.hasUpiShot.value = hasUpiShot;
    AuthSession.hasUpi.value = hasUpi;
    AuthSession.deposited.value = deposited;
    AuthSession.winnings.value = winnings;
    AuthSession.bonus.value = bonus;
    AuthSession.dailyLeft.value = dailyLeft;
    AuthSession.minAdd.value = _integer(limits['minAdd'], fallback: 5);
    AuthSession.maxAdd.value = _integer(limits['maxAdd'], fallback: 100);
    AuthSession.minWithdraw.value = _integer(
      limits['minWithdraw'],
      fallback: 20,
    );
    AuthSession.dailyLimit.value = _integer(
      limits['dailyLimit'],
      fallback: 100,
    );
    AuthSession.pushNotifications.value = notifSettings['push'] is bool
        ? notifSettings['push'] as bool
        : true;
    AuthSession.matchReminders.value = notifSettings['reminders'] is bool
        ? notifSettings['reminders'] as bool
        : true;
    AuthSession.resultAlerts.value = notifSettings['results'] is bool
        ? notifSettings['results'] as bool
        : true;
    AuthSession.maintenanceOn.value = maintenanceOn;
    AuthSession.maintenanceMessage.value = maintenanceMessage;
    AuthSession.maintenanceEta.value = maintenanceEta;
    AuthSession.paymentMethod.value = paymentMethod;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _string(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static String? _nullableString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int _integer(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? fallback;
    }
    return fallback;
  }
}

abstract final class AuthSession {
  static final ValueNotifier<String> userId = ValueNotifier<String>('');
  static final ValueNotifier<String> name = ValueNotifier<String>('Player');
  static final ValueNotifier<String> email = ValueNotifier<String>('');
  static final ValueNotifier<String?> picture = ValueNotifier<String?>(null);
  static final ValueNotifier<int> walletTotal = ValueNotifier<int>(1250);
  static final ValueNotifier<bool> gameOk = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> accountHeld = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> maintenanceOn = ValueNotifier<bool>(false);
  static final ValueNotifier<String> paymentMethod = ValueNotifier<String>(
    'gateway',
  );
  static final ValueNotifier<String> maintenanceMessage = ValueNotifier<String>(
    'We will be back shortly.',
  );
  static final ValueNotifier<String> maintenanceEta = ValueNotifier<String>('');
  static final ValueNotifier<String> ign = ValueNotifier<String>('');
  static final ValueNotifier<String> gameUid = ValueNotifier<String>('');
  static final ValueNotifier<String> upi = ValueNotifier<String>('');
  static final ValueNotifier<bool> hasUpi = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> hasUpiShot = ValueNotifier<bool>(false);
  static final ValueNotifier<int> deposited = ValueNotifier<int>(0);
  static final ValueNotifier<int> winnings = ValueNotifier<int>(0);
  static final ValueNotifier<int> bonus = ValueNotifier<int>(0);
  static final ValueNotifier<int> dailyLeft = ValueNotifier<int>(100);
  static final ValueNotifier<int> minAdd = ValueNotifier<int>(5);
  static final ValueNotifier<int> maxAdd = ValueNotifier<int>(100);
  static final ValueNotifier<int> minWithdraw = ValueNotifier<int>(20);
  static final ValueNotifier<int> dailyLimit = ValueNotifier<int>(100);
  static final ValueNotifier<bool> pushNotifications = ValueNotifier<bool>(
    true,
  );
  static final ValueNotifier<bool> matchReminders = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> resultAlerts = ValueNotifier<bool>(true);

  static void applyWallet({
    required int deposited,
    required int winnings,
    required int bonus,
    required int dailyLeft,
    required int minAdd,
    required int maxAdd,
    required int minWithdraw,
    required int dailyLimit,
    required String upi,
    required bool hasUpi,
    String paymentMethod = 'gateway',
  }) {
    AuthSession.deposited.value = deposited;
    AuthSession.winnings.value = winnings;
    AuthSession.bonus.value = bonus;
    AuthSession.walletTotal.value = deposited + winnings + bonus;
    AuthSession.dailyLeft.value = dailyLeft;
    AuthSession.minAdd.value = minAdd;
    AuthSession.maxAdd.value = maxAdd;
    AuthSession.minWithdraw.value = minWithdraw;
    AuthSession.dailyLimit.value = dailyLimit;
    AuthSession.upi.value = upi;
    AuthSession.hasUpi.value = hasUpi;
    AuthSession.paymentMethod.value = paymentMethod;
  }

  static void clear() {
    userId.value = '';
    name.value = 'Player';
    email.value = '';
    picture.value = null;
    walletTotal.value = 0;
    gameOk.value = false;
    accountHeld.value = false;
    maintenanceOn.value = false;
    paymentMethod.value = 'gateway';
    maintenanceMessage.value = 'We will be back shortly.';
    maintenanceEta.value = '';
    ign.value = '';
    gameUid.value = '';
    upi.value = '';
    hasUpi.value = false;
    hasUpiShot.value = false;
    deposited.value = 0;
    winnings.value = 0;
    bonus.value = 0;
    dailyLeft.value = 100;
    minAdd.value = 5;
    maxAdd.value = 100;
    minWithdraw.value = 20;
    dailyLimit.value = 100;
    pushNotifications.value = true;
    matchReminders.value = true;
    resultAlerts.value = true;
  }
}
