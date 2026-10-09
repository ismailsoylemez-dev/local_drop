import 'package:flutter/foundation.dart';

import 'constants.dart';

/// Uygulama logu: yalnız debug modda `[LD/<alan>] mesaj` basar.
abstract final class Log {
  static void d(String area, String msg) {
    if (kDebugMode) {
      debugPrint('[${AppConstants.logPrefix}/$area] $msg');
    }
  }

  /// Token/PIN gibi gizli değerleri maskeler: ilk 2 karakter + `**`.
  static String mask(String secret) {
    final visible = secret.length < AppConstants.maskVisibleChars
        ? secret
        : secret.substring(0, AppConstants.maskVisibleChars);
    return '$visible**';
  }
}
