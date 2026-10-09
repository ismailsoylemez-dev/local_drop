/// Sunucu açılamadı (ör. port aralığı dolu). [message] kullanıcıya gösterilir.
class ServerStartException implements Exception {
  const ServerStartException(this.message);
  final String message;

  @override
  String toString() => 'ServerStartException: $message';
}

/// İstenen ad kök klasör dışına çıkıyor ya da güvenli değil.
class PathEscapeException implements Exception {
  const PathEscapeException(this.name);
  final String name;

  @override
  String toString() => 'PathEscapeException: $name';
}

/// Akış [maxBytes] sınırını aştı.
class FileTooLargeException implements Exception {
  const FileTooLargeException(this.maxBytes);
  final int maxBytes;

  @override
  String toString() => 'FileTooLargeException: >$maxBytes bayt';
}
