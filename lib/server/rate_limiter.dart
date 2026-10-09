import 'dart:io';

import 'package:shelf/shelf.dart';

import '../core/constants.dart';

/// IP başına hatalı token/PIN denemesi sınırı (kayan pencere). Pencere içinde
/// [limit] hata dolunca o IP'nin tüm istekleri, en eski hata pencereden
/// çıkana kadar reddedilir. Doğru kimlik sayacı sıfırlar.
class RateLimiter {
  RateLimiter({
    this.limit = AppConstants.wrongTokenLimit,
    this.window = AppConstants.wrongTokenWindow,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int limit;
  final Duration window;
  final DateTime Function() _now;
  final Map<String, List<DateTime>> _failures = {};

  /// Engelliyse kalan süre, değilse null.
  Duration? retryAfter(String ip) {
    final failures = _prune(ip);
    if (failures == null || failures.length < limit) return null;
    return failures.first.add(window).difference(_now());
  }

  void recordFailure(String ip) {
    (_prune(ip) ?? (_failures[ip] = [])).add(_now());
  }

  void reset(String ip) => _failures.remove(ip);

  /// Pencere dışı kayıtları atar; boşaldıysa IP'yi siler.
  List<DateTime>? _prune(String ip) {
    final failures = _failures[ip];
    if (failures == null) return null;
    final cutoff = _now().subtract(window);
    failures.removeWhere((t) => !t.isAfter(cutoff));
    if (failures.isEmpty) {
      _failures.remove(ip);
      return null;
    }
    return failures;
  }
}

/// İstemci IP'si (shelf_io bağlantı bilgisi; yoksa `unknown`).
String clientIp(Request request) {
  final info = request.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
}

/// `Retry-After` saniyesi (yukarı yuvarlanır, en az 1).
int retryAfterSeconds(Duration wait) {
  final seconds = (wait.inMilliseconds / Duration.millisecondsPerSecond).ceil();
  return seconds < 1 ? 1 : seconds;
}
