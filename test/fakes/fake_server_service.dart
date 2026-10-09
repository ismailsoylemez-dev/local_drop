import 'dart:async';

import 'package:local_drop/server/server_event.dart';
import 'package:local_drop/services/server_service.dart';
import 'package:local_drop/services/storage_service.dart';

/// Ağ açmayan sunucu; olaylar elle yayınlanır.
class FakeServerService extends ServerService {
  FakeServerService(StorageService storage) : super(storage: storage);

  final eventsController = StreamController<ServerEvent>.broadcast();
  bool running = false;

  @override
  Stream<ServerEvent> get events => eventsController.stream;
  @override
  bool get isRunning => running;
  @override
  int? get port => running ? 8080 : null;
  @override
  String? get token => running ? 'Tok3nTok3nTok3n1' : null;
  @override
  String? get pin => running ? '123456' : null;

  @override
  Future<int> start() async {
    running = true;
    return 8080;
  }

  @override
  Future<void> stop() async => running = false;

  @override
  Future<void> dispose() async {
    running = false;
    await eventsController.close();
  }

  void emit(ServerEvent event) => eventsController.add(event);
}
