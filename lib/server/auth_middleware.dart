import 'dart:io';

import 'package:shelf/shelf.dart';

import '../core/constants.dart';
import '../core/log.dart';
import '../core/secrets.dart';
import 'rate_limiter.dart';
import 'responses.dart';

/// HttpOnly + SameSite=Strict token cookie'si.
String tokenCookie(String token) =>
    '${AppConstants.tokenCookieName}=$token; Path=/; HttpOnly; SameSite=Strict';

String? readCookie(Request request, String name) {
  final header = request.headers[HttpHeaders.cookieHeader];
  if (header == null) return null;
  for (final pair in header.split(';')) {
    final eq = pair.indexOf('=');
    if (eq < 0) continue;
    if (pair.substring(0, eq).trim() == name) {
      return pair.substring(eq + 1).trim();
    }
  }
  return null;
}

/// Hatalı deneme sınırı aşıldı → 429 + Retry-After.
Response tooManyAttempts(Duration wait) {
  final seconds = retryAfterSeconds(wait);
  final response = jsonError(
    HttpStatus.tooManyRequests,
    'Çok fazla hatalı deneme. $seconds sn sonra tekrar deneyin.',
  );
  return response.change(headers: {HttpHeaders.retryAfterHeader: '$seconds'});
}

/// `/login` dışındaki her istek `?t=` veya `ld_token` cookie'si ister.
/// Geçerli `?t=` ile gelen istekte cookie set edilir. Engellenen IP'nin
/// (çok hatalı deneme) tüm istekleri 429 alır; `/login` dahil.
Middleware authMiddleware({
  required String token,
  required RateLimiter limiter,
}) {
  return (inner) => (request) async {
    final ip = clientIp(request);
    if (limiter.retryAfter(ip) case final wait?) {
      Log.d('Auth', 'rate-limit ip=$ip ${retryAfterSeconds(wait)}s');
      return tooManyAttempts(wait);
    }

    final path = request.url.path;
    if (path == 'login') return inner(request);

    final query = request.url.queryParameters[AppConstants.tokenQueryParam];
    if (query != null && constantTimeEquals(query, token)) {
      limiter.reset(ip);
      final response = await inner(request);
      return response.change(
        headers: {HttpHeaders.setCookieHeader: tokenCookie(token)},
      );
    }

    final cookie = readCookie(request, AppConstants.tokenCookieName);
    if (cookie != null && constantTimeEquals(cookie, token)) {
      limiter.reset(ip);
      return inner(request);
    }

    // Kimliksiz ana sayfa → giriş (hatalı deneme sayılmaz).
    if (path.isEmpty &&
        request.method == 'GET' &&
        query == null &&
        cookie == null) {
      return Response.found('/login');
    }
    limiter.recordFailure(ip);
    return jsonError(HttpStatus.unauthorized, 'Yetkisiz');
  };
}
