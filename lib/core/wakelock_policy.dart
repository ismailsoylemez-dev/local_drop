/// Transfer başlangıç/bitişini bildiren taraf (upload/download handler'ları).
abstract interface class TransferObserver {
  void begin();
  void end();
}

/// CPU + Wi-Fi kilidi (Android'de native; testte sahte).
abstract interface class LockAdapter {
  void acquire();
  void release();
}

/// Kilit yalnız transfer sürerken tutulur: aktif sayı 0→1 alır, →0 bırakır.
/// Hatayla biten transfer de [end] çağırmalıdır (handler'larda finally).
class WakelockPolicy implements TransferObserver {
  WakelockPolicy(this._locks);

  final LockAdapter _locks;
  int _active = 0;

  int get active => _active;

  @override
  void begin() {
    if (_active++ == 0) _locks.acquire();
  }

  @override
  void end() {
    if (_active == 0) return;
    if (--_active == 0) _locks.release();
  }
}

/// Hiçbir şey yapmayan gözlemci (testler, kilitsiz kullanım).
class NoopTransferObserver implements TransferObserver {
  const NoopTransferObserver();

  @override
  void begin() {}

  @override
  void end() {}
}

/// Birden çok gözlemciye dağıtır (kilit politikası + ağ yeniden başlatma).
class MultiTransferObserver implements TransferObserver {
  const MultiTransferObserver(this.observers);

  final List<TransferObserver> observers;

  @override
  void begin() {
    for (final o in observers) {
      o.begin();
    }
  }

  @override
  void end() {
    for (final o in observers) {
      o.end();
    }
  }
}
