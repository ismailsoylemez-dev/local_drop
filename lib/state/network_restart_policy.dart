import '../core/wakelock_policy.dart';
import '../services/network_service.dart';

/// Sunucu çalışırken IP değişirse yeniden başlatma kararı. Aktif transfer
/// varsa bitene kadar ertelenir; ağ kesilmesi (NoNetwork) tek başına
/// yeniden başlatmaz (aynı ağ geri gelebilir).
class NetworkRestartPolicy implements TransferObserver {
  NetworkRestartPolicy({required this.restart});

  /// Yeni IP ile yeniden başlat (controller).
  final void Function(String ip) restart;

  String? _servingIp;
  String? _pendingIp;
  int _active = 0;

  int get activeTransfers => _active;
  String? get pendingIp => _pendingIp;

  void serverStarted(String ip) {
    _servingIp = ip;
    _pendingIp = null;
  }

  void serverStopped() {
    _servingIp = null;
    _pendingIp = null;
  }

  void onNetwork(NetworkResult result) {
    final serving = _servingIp;
    if (serving == null || result is! Connected) return;
    _pendingIp = result.ip == serving ? null : result.ip;
    _maybeRestart();
  }

  @override
  void begin() => _active++;

  @override
  void end() {
    if (_active == 0) return;
    _active--;
    _maybeRestart();
  }

  void _maybeRestart() {
    final ip = _pendingIp;
    if (ip == null || _active > 0) return;
    _pendingIp = null;
    _servingIp = ip;
    restart(ip);
  }
}
