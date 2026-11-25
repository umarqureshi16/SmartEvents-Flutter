import 'package:flutter_test/flutter_test.dart';
import 'package:smartevents/core/validators.dart';
import 'package:smartevents/screens/auth/auth_screens.dart' show tokenFrom;

void main() {
  test('email and name follow the server rules', () {
    expect(V.email('a@b'), isNotNull);
    expect(V.email('ayesha@example.com'), isNull);
    expect(V.name('A'), isNotNull);
    expect(V.name('A' * 51), isNotNull);
    expect(V.name('Ayesha'), isNull);
  });

  test('new passwords must meet every rule', () {
    expect(V.newPassword('abcdefgh'), isNotNull);
    expect(V.newPassword('Ev3nt!Plan#26'), isNull);
    expect(V.newPassword('Ayesha!2026x', name: 'Ayesha Khan'), isNotNull);
  });

  test('prices and lengths', () {
    expect(V.positive('0'), isNotNull);
    expect(V.positive('25'), isNull);
    expect(V.nonNegative('-1'), isNotNull);
    expect(V.length('short', min: 10, label: 'Description'), 'Description must be at least 10 characters');
  });

  test('tokens come out of pasted links', () {
    expect(tokenFrom('https://smart-events-puce.vercel.app/reset-password/abc123'), 'abc123');
    expect(tokenFrom('https://x.app/verify-email?token=t0k'), 't0k');
    expect(tokenFrom(' raw-token '), 'raw-token');
  });
}
