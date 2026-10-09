import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/log.dart';
import '../services/network_service.dart';

enum ServerStatus { stopped, starting, running, error }

/// UI'nin tek durum kaynağı. start/stop F3'e kadar iskelet (stub).
class ServerController extends ChangeNotifier {
  ServerController({required NetworkService network}) {
    _networkSub = network.watch().listen((result) {
      _network = result;
      notifyListeners();
    });
  }

  late final StreamSubscription<NetworkResult> _networkSub;

  ServerStatus _status = ServerStatus.stopped;
  String? _url;
  String? _pin;
  String? _errorMessage;
  NetworkResult? _network;

  ServerStatus get status => _status;
  String? get url => _url;
  String? get pin => _pin;
  String? get errorMessage => _errorMessage;

  /// null = henüz kontrol edilmedi.
  NetworkResult? get network => _network;
  bool get canStart => _network is Connected;

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

  @override
  void dispose() {
    _networkSub.cancel();
    super.dispose();
  }
}
