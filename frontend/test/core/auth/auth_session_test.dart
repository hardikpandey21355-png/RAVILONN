import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/auth/auth_session.dart';

void main() {
  test('session maps backend user and wallet values into shared state', () {
    addTearDown(AuthSession.clear);
    final session = AuthSessionData.fromJson({
      'ok': true,
      'user': {
        'uid': 'user-123',
        'name': 'Ravi',
        'email': 'ravi@example.com',
        'picture': 'https://example.com/avatar.png',
        'ign': 'RaviFF',
        'gameUid': '123456',
        'upi': 'ravi@upi',
        'hasUpiShot': true,
      },
      'wallet': {'deposited': 400, 'winnings': 100, 'bonus': 25, 'total': 525},
      'gameOk': true,
      'paymentMethod': 'off',
      'maintenance': {'on': true, 'message': 'Back soon', 'eta': '10 minutes'},
    });

    session.apply();

    expect(AuthSession.userId.value, 'user-123');
    expect(AuthSession.name.value, 'Ravi');
    expect(AuthSession.email.value, 'ravi@example.com');
    expect(AuthSession.picture.value, 'https://example.com/avatar.png');
    expect(AuthSession.walletTotal.value, 525);
    expect(AuthSession.gameOk.value, isTrue);
    expect(AuthSession.ign.value, 'RaviFF');
    expect(AuthSession.gameUid.value, '123456');
    expect(AuthSession.upi.value, 'ravi@upi');
    expect(AuthSession.hasUpiShot.value, isTrue);
    expect(AuthSession.maintenanceOn.value, isTrue);
    expect(AuthSession.maintenanceMessage.value, 'Back soon');
    expect(AuthSession.maintenanceEta.value, '10 minutes');
    expect(AuthSession.paymentMethod.value, 'off');
  });
}
