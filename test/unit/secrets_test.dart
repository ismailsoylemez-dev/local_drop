import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/secrets.dart';

void main() {
  test('token: 16 karakter base62, her seferinde farklı', () {
    final a = generateToken();
    expect(a, matches(RegExp(r'^[0-9A-Za-z]{16}$')));
    expect(generateToken(), isNot(a));
  });

  test('PIN: 6 rakam', () {
    expect(generatePin(), matches(RegExp(r'^\d{6}$')));
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals('abc', 'abc'), isTrue);
    expect(constantTimeEquals('abc', 'abd'), isFalse);
    expect(constantTimeEquals('abc', 'ab'), isFalse);
    expect(constantTimeEquals('', 'a'), isFalse);
    expect(constantTimeEquals('', ''), isTrue);
  });
}
