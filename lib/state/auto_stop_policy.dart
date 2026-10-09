import '../core/wakelock_policy.dart';

/// Sunucu açıkken [timeout] boyunca transfer olmazsa kapatma kararı.
/// Aktif transfer varken asla; transfer başlangıcı/bitişi süreyi sıfırlar.
class AutoStopPolicy implements TransferObserver {
  AutoStopPolicy({required this.timeout, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Güncel ayar (dk → süre); [Duration.zero] = kapalı.
  final Duration Function() timeout;
  final DateTime Function() _now;

  DateTime? _lastActivity;
  int _active = 0;

  void serverStarted() {
    _lastActivity = _now();
    _active = 0;
  }

  void serverStopped() => _lastActivity = null;

  @override
  void begin() {
    _active++;
    _lastActivity = _now();
  }

  @override
  void end() {
    if (_active > 0) _active--;
    _lastActivity = _now();
  }

  bool shouldStop() {
    final last = _lastActivity;
    final limit = timeout();
    if (last == null || limit <= Duration.zero || _active > 0) return false;
    return _now().difference(last) >= limit;
  }
}
