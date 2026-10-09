import 'dart:async';

import 'package:local_drop/services/background_service.dart';

class FakeBackgroundService implements BackgroundService {
  final eventsController = StreamController<BackgroundEvent>.broadcast();
  bool permissionGranted = true;
  String? startError;
  final started = <String>[];
  int stopCalls = 0;
  final updated = <String>[];

  @override
  Stream<BackgroundEvent> get events => eventsController.stream;

  @override
  Future<bool> ensureNotificationPermission() async => permissionGranted;

  @override
  Future<String?> start(String address) async {
    started.add(address);
    return startError;
  }

  @override
  Future<void> update(String address) async => updated.add(address);

  @override
  Future<void> stop() async => stopCalls++;
}
