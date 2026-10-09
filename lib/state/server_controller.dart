import 'package:flutter/foundation.dart';

import '../core/log.dart';

enum ServerStatus { stopped, starting, running, error }

/// UI'nin tek durum kaynağı. F1'de start/stop yalnız iskelet (stub).
class ServerController extends ChangeNotifier {
  ServerStatus _status = ServerStatus.stopped;
  String? _url;
  String? _pin;
  String? _errorMessage;

  ServerStatus get status => _status;
  String? get url => _url;
  String? get pin => _pin;
  String? get errorMessage => _errorMessage;

  Future<void> start() async {
    // TODO(F3): ServerService ile gerçek sunucu başlatma.
    Log.d('Server', 'start (stub)');
  }

  Future<void> stop() async {
    // TODO(F3): ServerService.stop.
    Log.d('Server', 'stop (stub)');
    _status = ServerStatus.stopped;
    _url = null;
    _pin = null;
    _errorMessage = null;
    notifyListeners();
  }
}
