import 'dart:math';

import 'constants.dart';

/// Base62 erişim token'ı (Random.secure).
String generateToken([Random? random]) {
  final r = random ?? Random.secure();
  const alphabet = AppConstants.tokenAlphabet;
  return String.fromCharCodes(
    List.generate(
      AppConstants.tokenLength,
      (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length)),
    ),
  );
}

/// Sabit uzunlukta rakamlardan PIN (token'dan bağımsız).
String generatePin([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(AppConstants.pinLength, (_) => r.nextInt(10)).join();
}

/// Uzunluk dışında içerikten bağımsız süren karşılaştırma.
bool constantTimeEquals(String a, String b) {
  final x = a.codeUnits;
  final y = b.codeUnits;
  var diff = x.length ^ y.length;
  for (var i = 0; i < x.length; i++) {
    diff |= x[i] ^ (i < y.length ? y[i] : 0);
  }
  return diff == 0;
}
